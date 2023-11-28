import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:weepy/classes/sender.dart';
import 'package:weepy/models.dart';

import 'worker_commands.dart' as commands;
import 'dart:isolate';
import 'dart:ui';
import 'package:workmanager/workmanager.dart';

import 'receiver.dart';
import 'worker_commands.dart';

enum MyTasks { receive, send }

final _workManager = Workmanager();

@pragma("vm:entry-point")
void _callBack() {
  _workManager.executeTask((taskName, inputData) async {
    final task =
        MyTasks.values.singleWhere((element) => element.name == taskName);
    switch (task) {
      case MyTasks.receive:
        final receiverMap = inputData!;
        final receiver = Receiver(
            useDb: receiverMap["useDb"],
            port: receiverMap["port"],
            saveToTemp: receiverMap["saveToTemp"],
            code: receiverMap["code"],
            onDownloadUpdatePercent: (percent) {
              final sendPort =
                  IsolateNameServer.lookupPortByName(MyTasks.receive.name);
              sendPort?.send(UpdatePercent(percent));
            });
        await receiver.listen();
        return true;
      case MyTasks.send:
        final senderMap = inputData!;
        final fileDirs = senderMap["files"] as List<String>;
        final files = fileDirs.map((e) => File(e));
        final platformFiles = files.map((e) => PlatformFile(
            path: e.path, name: basename(e.path), size: e.lengthSync()));
        final device = Device.fromMap(senderMap);
        final port = IsolateNameServer.lookupPortByName(MyTasks.send.name);
        await Sender.send(device, platformFiles,
            onUploadProgress: (percent) => port?.send(UpdatePercent(percent)));
        return true;
    }
  });
}

Future<void> initalize() => _workManager.initialize(_callBack);

Future<void> cancelSend() => _workManager.cancelByUniqueName(MyTasks.send.name);

Future<void> cancelReceive() =>
    _workManager.cancelByUniqueName(MyTasks.receive.name);

ReceivePort runReceiver(
    Receiver receiver, void Function(double percent)? onReceivePercent) {
  final port = ReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.receive.name);
  port.listen((message) {
    switch (message) {
      case final commands.UpdatePercent e:
        onReceivePercent?.call(e.newPercent);
        break;
      default:
        throw Error();
    }
  });
  _workManager.registerOneOffTask(MyTasks.receive.name, MyTasks.receive.name,
      inputData: receiver.map, existingWorkPolicy: ExistingWorkPolicy.keep);
  return port;
}

ReceivePort runSender(Device device, List<String> filePaths,
    void Function(double percent)? onSendPercent) {
  final inputMap = device.map..addAll({"files": filePaths});
  final port = ReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.send.name);
  port.listen((message) {
    switch (message) {
      case final commands.UpdatePercent e:
        onSendPercent?.call(e.newPercent);
        break;
      default:
        throw Error();
    }
  });
  _workManager.registerOneOffTask(MyTasks.send.name, MyTasks.send.name,
      inputData: inputMap, existingWorkPolicy: ExistingWorkPolicy.keep);
  return port;
}
