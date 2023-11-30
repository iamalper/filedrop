import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/src/animation/animation_controller.dart';
import 'package:path/path.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/classes/sender.dart';
import 'package:weepy/models.dart';

import 'worker_messages.dart' as messages;
import 'dart:isolate';
import 'dart:ui';
import 'package:workmanager/workmanager.dart';

import 'receiver.dart';

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
              sendPort?.send(messages.UpdatePercent(percent));
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
            onUploadProgress: (percent) =>
                port?.send(messages.UpdatePercent(percent)));
        return true;
    }
  });
}

class IsolatedSender extends Sender {
  ///Run [Sender] from a worker.
  ///
  ///Call [initalize()] before.
  Future<void> send(Device device, Iterable<PlatformFile> files,
      {AnimationController? uploadAnimC,
      bool useDb = true,
      void Function(double percent)? onUploadProgress}) async {
    final fileDirs = files.map((e) => e.path!);
    final map = device.map..addAll({"files": fileDirs});
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.send.name);
    final streamSubscription = port.listen((message) {
      switch (message as messages.SenderMessage) {
        case final messages.UpdatePercent e:
          onUploadProgress?.call(e.newPercent);
          break;
        case final messages.FiledropError e:
          throw e.exception;
        default:
          throw Error();
      }
    });
    _workManager.registerOneOffTask(MyTasks.send.name, MyTasks.send.name,
        inputData: map);
    await streamSubscription.asFuture();
  }

  static Future<void> cancelSend() =>
      _workManager.cancelByUniqueName(MyTasks.send.name);
}

Future<void> initalize() => _workManager.initialize(_callBack);

class IsolatedReceiver extends Receiver {
  ///Runs [Receiver] from a worker.
  ///
  ///Call [initalize()] before.
  IsolatedReceiver({
    super.onDownloadUpdatePercent,
    super.useDb,
    super.saveToTemp,
    super.port,
    super.onDownloadStart,
    super.onFileDownloaded,
    super.onAllFilesDownloaded,
    super.onDownloadError,
    super.code,
  });

  ///Starts worker and runs [Receiver.listen]
  ///
  ///If called twice, it has no effect.
  @override
  Future<int> listen() async {
    final permissionStatus = await super.checkPermission();
    if (!permissionStatus) {
      throw NoStoragePermissionException();
    }
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.receive.name);
    port.listen((message) {
      switch (message as messages.ReceiverMessage) {
        case final messages.UpdatePercent e:
          super.onDownloadUpdatePercent?.call(e.newPercent);
          break;
        case final messages.FiledropError e:
          super.onDownloadError?.call(e.exception);
          break;
        case final messages.FileDownloaded e:
          super.onFileDownloaded?.call(e.file);
          break;
        case final messages.AllFilesDownloaded e:
          super.onAllFilesDownloaded?.call(e.files);
        default:
          throw Error();
      }
    });
    _workManager.registerOneOffTask(MyTasks.receive.name, MyTasks.receive.name,
        inputData: super.map, existingWorkPolicy: ExistingWorkPolicy.keep);
    return super.code;
  }

  ///Stops [Receiver] worker.
  static Future<void> cancel() =>
      _workManager.cancelByUniqueName(MyTasks.receive.name);
}
