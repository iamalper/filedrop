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

enum MyTasks { receive, send }

enum ReceiverIsolatePorts { percentUpdate, command }

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
              final sendPort = IsolateNameServer.lookupPortByName(
                  ReceiverIsolatePorts.percentUpdate.name);
              sendPort?.send(percent);
            });
        final receivePort = ReceivePort("commandPort");
        IsolateNameServer.registerPortWithName(
            receivePort.sendPort, ReceiverIsolatePorts.command.name);
        await receiver.listen();
        receivePort.listen((message) async {
          switch (message) {
            case final commands.Stop _:
              await receiver.stopListening();
              receivePort.close();
            default:
              throw Exception("Unsupported command for receiver");
          }
        });
        return true;
      case MyTasks.send:
        final senderMap = inputData!;
        final fileDirs = senderMap["files"] as List<String>;
        final files = fileDirs.map((e) => File(e));
        final platformFiles = files.map((e) => PlatformFile(
            path: e.path, name: basename(e.path), size: e.lengthSync()));
        final device = Device.fromMap(senderMap);
        await Sender.send(device, platformFiles);
        return true;
    }
  });
}

Future<void> initalize() async {
  throw UnimplementedError();
  // ignore: dead_code
  await _workManager.initialize(_callBack);
}

ReceivePort runReceiver(Receiver receiver) {
  final port = ReceivePort();
  IsolateNameServer.registerPortWithName(
      port.sendPort, ReceiverIsolatePorts.percentUpdate.name);
  _workManager.registerOneOffTask(MyTasks.receive.name, MyTasks.receive.name,
      inputData: receiver.map, existingWorkPolicy: ExistingWorkPolicy.keep);
  return port;
}
