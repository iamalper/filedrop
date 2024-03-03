import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:weepy/classes/notifications.dart' as notifications;
import 'package:weepy/classes/sender.dart';
import 'package:weepy/classes/workers/worker_interface.dart';
import 'package:weepy/classes/workers/worker_messages.dart' as messages;
import 'package:weepy/models.dart';
import 'base_worker.dart';

class IsolatedSender extends Sender implements BaseWorker {
  IsolatedSender({super.onUploadProgress});
  //TODO: Test completer
  final aliveCheckCompleter = Completer<bool>();
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

  @override
  Future<void> send(Device device, Iterable<PlatformFile> files,
      {bool useDb = true, bool progressNotification = true}) async {
    try {
      await initialize();
      if (progressNotification) {
        progressNotification = await notifications.initialize();
      }
      final fileDirs = files.map((e) => e.path!);
      final map = device.map;
      for (var i = 0; i < fileDirs.length; i++) {
        map["file$i"] = fileDirs.elementAt(i);
      }
      map["useDb"] = useDb;

      final exitBlock = Completer<void>();
      getReceivePort().listen((data) async {
        //Listen incoming messages
        switch (messages.MessageType.values[data["type"]]) {
          case messages.MessageType.updatePercent:
            final message = messages.UpdatePercent.fromMap(data);
            if (progressNotification) {
              await notifications
                  .showUpload((message.newPercent * 100).round());
            }
            onUploadProgress?.call(message.newPercent);
            break;
          case messages.MessageType.completed:
            final _ = messages.Completed.fromMap(data);
            exitBlock.complete();
          case messages.MessageType.alive:
            aliveCheckCompleter.complete(true);
          default:
            throw Error();
        }
      });
      await workManager.registerOneOffTask(Tasks.send.name, Tasks.send.name,
          inputData: map);
      if (progressNotification) {
        //Create notification
        await notifications.showUpload(0);
      }
      await exitBlock.future;
      if (progressNotification) {
        await notifications.cancelUpload();
      }
    } finally {
      unregisterReceivePort();
    }
  }

  @override
  Future<void> stop() async {
    unregisterReceivePort();
    await workManager.cancelByUniqueName(Tasks.send.name);
  }

  @override
  ReceivePort getReceivePort() {
    final receivePort = ReceivePort();
    final isRegistered = IsolateNameServer.registerPortWithName(
        receivePort.sendPort, PortNames.sender2main.name);
    assert(isRegistered);
    return receivePort;
  }

  @override
  void unregisterReceivePort() {
    IsolateNameServer.removePortNameMapping(PortNames.sender2main.name);
  }

  @override
  SendPort? getSendPort() {
    final sendPort =
        IsolateNameServer.lookupPortByName(PortNames.main2sender.name);
    return sendPort;
  }
}
