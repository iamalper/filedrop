import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:weepy/classes/notifications.dart' as notifications;
import 'package:weepy/classes/sender.dart';
import 'package:weepy/classes/workers/isolated_receiver.dart';
import 'package:weepy/classes/workers/worker_interface.dart';
import 'package:weepy/classes/workers/worker_messages.dart' as messages;
import 'package:weepy/models.dart';

class IsolatedSender extends Sender {
  IsolatedSender({super.onUploadProgress});

  ///Returns whether [IsolatedReceiver] active in a worker.
  Future<bool> isActive() async {
    //TODO
    throw UnimplementedError();
  }

  @override
  Future<void> send(Device device, Iterable<PlatformFile> files,
      {bool useDb = true, bool progressNotification = true}) async {
    final port = await initialize();
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
    await workManager.registerOneOffTask(MyTasks.send.name, MyTasks.send.name,
        inputData: map);
    if (progressNotification) {
      //Create notification
      await notifications.showUpload(0);
    }
    await exitBlock.future;
    if (progressNotification) {
      await notifications.cancelUpload();
    }
  }

  @override
  Future<void> cancel() => workManager.cancelByUniqueName(MyTasks.send.name);
}
