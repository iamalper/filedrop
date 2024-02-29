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

import 'base_worker.dart';

class IsolatedReceiver extends Receiver implements BaseWorker {
  ///If [true] creates and manages progress notification.
  bool progressNotification;

  //TODO: Test completer
  final aliveCheckCompleter = Completer<bool>();

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

  @override
  Future<bool> isActive() async {
    final sendPort = getSendPort();
    if (sendPort == null) {
      return false;
    }
    sendPort.send(const messages.Alive().map);
    const waitDuration = Duration(seconds: 5);
    final aliveCanceller = Future.delayed(
      waitDuration,
      () => aliveCheckCompleter.complete(false),
    );
    final alive = await aliveCheckCompleter.future;
    if (alive) {
      aliveCanceller.ignore();
    }
    return alive;
  }

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

    getReceivePort().listen(_portCallback);
    await workManager.registerOneOffTask(Tasks.receive.name, Tasks.receive.name,
        inputData: super.map, existingWorkPolicy: ExistingWorkPolicy.keep);
    return super.code;
  }

  @override
  Future<void> stop() async {
    if (progressNotification) {
      await notifications.cancelDownload();
    }
    await workManager.cancelByUniqueName(Tasks.receive.name);
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
        case messages.MessageType.alive:
          aliveCheckCompleter.complete(true);
        default:
          throw Error();
      }
    } on Exception catch (e) {
      log("Error", name: "IsolatedReceiver", error: e);
      rethrow;
    }
  }

  @override
  ReceivePort getReceivePort() {
    final receivePort = ReceivePort();
    final isRegistered = IsolateNameServer.registerPortWithName(
        receivePort.sendPort, PortNames.receiver2main.name);
    assert(isRegistered);
    return receivePort;
  }

  @override
  SendPort? getSendPort() {
    final sendPort =
        IsolateNameServer.lookupPortByName(PortNames.main2receiver.name);
    return sendPort;
  }
}
