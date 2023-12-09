import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
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
    try {
      final task =
          MyTasks.values.singleWhere((element) => element.name == taskName);
      switch (task) {
        case MyTasks.receive:
          SendPort? getReceiverPort() =>
              IsolateNameServer.lookupPortByName(MyTasks.receive.name);
          final exitBlock = Completer<bool>();
          final receiverMap = inputData!;
          final receiver =
              Receiver.fromMap(receiverMap, onDownloadUpdatePercent: (percent) {
            final sendPort = getReceiverPort();
            sendPort?.send(messages.UpdatePercent(percent).map);
          }, onDownloadError: (error) {
            final sendPort = getReceiverPort();
            if (sendPort != null) {
              sendPort.send(messages.FiledropError(error).map);
            } else {
              exitBlock.completeError(error);
            }
          }, onDownloadStart: () {
            final sendPort = getReceiverPort();
            sendPort?.send(const messages.DownloadStarted().map);
          }, onAllFilesDownloaded: (files) {
            final sendPort = getReceiverPort();
            sendPort?.send(messages.AllFilesDownloaded(files).map);
            exitBlock.complete(true);
          }, onFileDownloaded: (file) {
            final sendPort = getReceiverPort();
            sendPort?.send(messages.FileDownloaded(file).map);
          });
          await receiver.listen();
          return exitBlock.future;
        case MyTasks.send:
          final senderMap = inputData!;
          final fileDirs = <String>[];
          for (var a = 0; senderMap["file$a"] != null; a++) {
            fileDirs.add(senderMap["file$a"]);
          }
          assert(fileDirs.isNotEmpty);
          final files = fileDirs.map((e) => File(e));
          final platformFiles = files.map((e) => PlatformFile(
              path: e.path, name: basename(e.path), size: e.lengthSync()));
          final device = Device.fromMap(senderMap);
          SendPort? getSenderPort() =>
              IsolateNameServer.lookupPortByName(MyTasks.send.name);
          await Sender().send(device, platformFiles,
              useDb: senderMap["useDb"],
              onUploadProgress: (percent) =>
                  getSenderPort()?.send(messages.UpdatePercent(percent).map));
          getSenderPort()?.send(const messages.Completed().map);
          return true;
      }
    } on Exception {
      rethrow;
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
    await initalize();
    if (progressNotification) {
      progressNotification = await notifications.initalise();
    }
    final fileDirs = files.map((e) => e.path!);
    final map = device.map;
    for (var i = 0; i < fileDirs.length; i++) {
      map["file$i"] = fileDirs.elementAt(i);
    }
    map["useDb"] = useDb;
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.send.name);

    final exitBlock = Completer<void>();
    port.listen((data) async {
      switch (messages.MessageType.values[data["type"]]) {
        case messages.MessageType.updatePercent:
          final message = messages.UpdatePercent.fromMap(data);
          if (progressNotification) {
            await notifications.showUpload((message.newPercent * 100).round());
          }
          onUploadProgress?.call(message.newPercent);
          break;
        case messages.MessageType.completed:
          final _ = messages.Completed.fromMap(data);
          exitBlock.complete();
        default:
          throw Error();
      }
    });
    await _workManager.registerOneOffTask(MyTasks.send.name, MyTasks.send.name,
        inputData: map);
    if (progressNotification) {
      await notifications.showDownload(0);
    }
    if (progressNotification) {
      await notifications.cancelDownload();
    }
    return exitBlock.future;
  }

  @override
  Future<void> cancel() => _workManager.cancelByUniqueName(MyTasks.send.name);
}

Future<void> initalize() async {
  await _workManager.initialize(_callBack, isInDebugMode: kDebugMode);
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
    await initalize();
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
    await _workManager.registerOneOffTask(
        MyTasks.receive.name, MyTasks.receive.name,
        inputData: super.map, existingWorkPolicy: ExistingWorkPolicy.keep);
    return super.code;
  }

  @override
  Future<void> stopListening() async {
    if (progressNotification) {
      await notifications.cancelDownload();
    }
    await _workManager.cancelByUniqueName(MyTasks.receive.name);
  }

  Future<void> _portCallback(data) async {
    final type = messages.MessageType.values[data["type"]];
    switch (type) {
      case messages.MessageType.updatePercent:
        final message = messages.UpdatePercent.fromMap(data);
        if (progressNotification) {
          await notifications.showDownload((message.newPercent * 100).round());
        }
        super.onDownloadUpdatePercent?.call(message.newPercent);
        break;
      case messages.MessageType.filedropError:
        final message = messages.FiledropError.fromMap(data);
        if (progressNotification) {
          await notifications.cancelDownload();
        }
        super.onDownloadError?.call(message.exception);
        break;
      case messages.MessageType.fileDownloaded:
        final message = messages.FileDownloaded.fromMap(data);
        super.onFileDownloaded?.call(message.file);
        break;
      case messages.MessageType.allFilesDownloaded:
        final message = messages.AllFilesDownloaded.fromMap(data);
        if (progressNotification) {
          await notifications.cancelDownload();
        }
        super.onAllFilesDownloaded?.call(message.files.toList());
        break;
      case messages.MessageType.downloadStarted:
        final _ = messages.DownloadStarted.fromMap(data);
        super.onDownloadStart?.call();
      default:
        throw Error();
    }
  }
}
