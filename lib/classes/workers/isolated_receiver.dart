import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/classes/notifications.dart' as notifications;
import 'package:weepy/classes/receiver.dart';
import 'package:weepy/classes/workers/worker_interface.dart';
import 'package:weepy/classes/workers/worker_messages.dart' as messages;
import 'package:workmanager/workmanager.dart';

class IsolatedReceiver extends Receiver {
  ///If [true] creates and manages progress notification.
  bool progressNotification;

  ///Runs [Receiver] from a worker.
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
  ///If necessary, requests permission. Throws [NoStoragePermissionException]
  ///if permission rejected by user.
  @override
  Future<int> listen() async {
    await initialize();
    if (progressNotification) {
      progressNotification = await notifications.initialize();
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
    await workManager.registerOneOffTask(
        MyTasks.receive.name, MyTasks.receive.name,
        inputData: super.map, existingWorkPolicy: ExistingWorkPolicy.keep);
    return super.code;
  }

  @override
  Future<void> stopListening() async {
    if (progressNotification) {
      await notifications.cancelDownload();
    }
    await workManager.cancelByUniqueName(MyTasks.receive.name);
  }

  Future<void> _portCallback(data) async {
    try {
      final type = messages.MessageType.values[data["type"]];
      switch (type) {
        case messages.MessageType.updatePercent:
          final message = messages.UpdatePercent.fromMap(data);
          if (progressNotification) {
            await notifications
                .showDownload((message.newPercent * 100).round());
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
    } on Exception catch (e) {
      log("Interface error", name: "IsolatedReceiver", error: e);
      rethrow;
    }
  }
}
