import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/animation.dart';
import 'package:path/path.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/classes/sender.dart';
import 'package:weepy/models.dart';

import '../notifications.dart' as notifications;
import 'worker_messages.dart' as messages;
import 'dart:isolate';
import 'dart:ui';
import 'package:workmanager/workmanager.dart';

import '../receiver.dart';

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
        await Sender().send(device, platformFiles,
            onUploadProgress: (percent) =>
                port?.send(messages.UpdatePercent(percent)));
        return true;
    }
  });
}

class IsolatedSender extends Sender {
  ///If [true] creates and manages progress notification.
  ///
  ///[progressNotification] will change to [false] if user denies permission
  bool progressNotification;
  IsolatedSender({this.progressNotification = true});

  ///Run [Sender] from a worker.
  ///
  ///Call [initalize()] before.
  @override
  Future<void> send(Device device, Iterable<PlatformFile> files,
      {@Deprecated("It has no effect. Prefer onUploadProgress instead")
      AnimationController? uploadAnimC,
      bool useDb = true,
      void Function(double percent)? onUploadProgress}) async {
    if (progressNotification) {
      progressNotification = await notifications.initalise();
    }
    final fileDirs = files.map((e) => e.path!);
    final map = device.map..addAll({"files": fileDirs});
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.send.name);
    final streamSubscription = port.listen((message) async {
      switch (message as messages.SenderMessage) {
        case final messages.UpdatePercent e:
          if (progressNotification) {
            await notifications.showUpload((e.newPercent * 100).round());
          }
          onUploadProgress?.call(e.newPercent);
          break;
        case final messages.FiledropError e:
          if (progressNotification) {
            await cancelSend();
          }
          throw e.exception;
        default:
          throw Error();
      }
    });
    _workManager.registerOneOffTask(MyTasks.send.name, MyTasks.send.name,
        inputData: map);
    if (progressNotification) {
      await notifications.showDownload(0);
    }
    await streamSubscription.asFuture();
    if (progressNotification) {
      await notifications.cancelDownload();
    }
  }

  static Future<void> cancelSend() =>
      _workManager.cancelByUniqueName(MyTasks.send.name);
}

Future<void> initalize() async {
  await _workManager.initialize(_callBack);
}

class IsolatedReceiver extends Receiver {
  ///If [true] creates and manages progress notification.
  bool progressNotification;

  ///Runs [Receiver] from a worker.
  ///
  ///Call [initalize()] before.
  IsolatedReceiver(
      {super.onDownloadUpdatePercent,
      super.useDb,
      super.saveToTemp,
      super.port,
      super.onDownloadStart,
      super.onFileDownloaded,
      super.onAllFilesDownloaded,
      super.onDownloadError,
      super.code,
      this.progressNotification = true});

  ///Starts worker and runs [Receiver.listen]
  ///
  ///If called twice, it has no effect.
  @override
  Future<int> listen() async {
    if (progressNotification) {
      progressNotification = await notifications.initalise();
    }
    if (!saveToTemp) {
      final permissionStatus = await super.checkPermission();
      if (!permissionStatus) {
        throw NoStoragePermissionException();
      }
    }
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.receive.name);
    port.listen(_portCallback);
    _workManager.registerOneOffTask(MyTasks.receive.name, MyTasks.receive.name,
        inputData: super.map, existingWorkPolicy: ExistingWorkPolicy.keep);
    return super.code;
  }

  Future<void> _portCallback(message) async {
    switch (message as messages.ReceiverMessage) {
      case final messages.UpdatePercent e:
        if (progressNotification) {
          await notifications.showDownload((e.newPercent * 100).round());
        }
        super.onDownloadUpdatePercent?.call(e.newPercent);
        break;
      case final messages.FiledropError e:
        if (progressNotification) {
          await notifications.cancelDownload();
        }
        super.onDownloadError?.call(e.exception);
        break;
      case final messages.FileDownloaded e:
        super.onFileDownloaded?.call(e.file);
        break;
      case final messages.AllFilesDownloaded e:
        if (progressNotification) {
          await notifications.cancelDownload();
        }
        super.onAllFilesDownloaded?.call(e.files);
      case final messages.DownloadStarted _:
        if (progressNotification) {
          await notifications.showDownload(0);
        }
        super.onDownloadStart?.call();
      default:
        if (progressNotification) {
          await notifications.cancelDownload();
        }
        throw Error();
    }
  }

  ///Stops [Receiver] worker.
  static Future<void> cancelReceive() async {
    await notifications.cancelDownload();
    await _workManager.cancelByUniqueName(MyTasks.receive.name);
  }
}
