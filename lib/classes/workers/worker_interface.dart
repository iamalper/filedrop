import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:weepy/classes/sender.dart';
import 'package:weepy/models.dart';

import 'worker_messages.dart' as messages;
import 'dart:isolate';
import 'dart:ui';
import 'package:workmanager/workmanager.dart';

import '../receiver.dart';

enum MyTasks { receive, send }

enum PortName { main2receiver, main2sender }

final workManager = Workmanager();
@pragma("vm:entry-point")
void _callBack() {
  workManager.executeTask((taskName, inputData) async {
    try {
      final task =
          MyTasks.values.singleWhere((element) => element.name == taskName);
      switch (task) {
        case MyTasks.receive:
          SendPort? getSendPort() =>
              IsolateNameServer.lookupPortByName(MyTasks.receive.name);

          final receiverPort = ReceivePort();
          IsolateNameServer.registerPortWithName(
              receiverPort.sendPort, PortName.main2receiver.name);
          receiverPort.listen((message) {
            //TODO: Test alive feature
            if (message["data"] == messages.MessageType.alive) {
              log("Got alive message.", name: "Receiver worker");
              getSendPort()?.send(const messages.Alive().map);
            }
          });
          final exitBlock = Completer<bool>();
          final receiverMap = inputData!;
          final receiver =
              Receiver.fromMap(receiverMap, onDownloadUpdatePercent: (percent) {
            final sendPort = getSendPort();
            sendPort?.send(messages.UpdatePercent(percent).map);
          }, onDownloadError: (error) {
            final sendPort = getSendPort();
            if (sendPort != null) {
              sendPort.send(messages.FiledropError(error).map);
            } else {
              exitBlock.completeError(error);
            }
          }, onDownloadStart: () {
            final sendPort = getSendPort();
            sendPort?.send(const messages.DownloadStarted().map);
          }, onAllFilesDownloaded: (files) {
            final sendPort = getSendPort();
            sendPort?.send(messages.AllFilesDownloaded(files).map);
            exitBlock.complete(true);
          }, onFileDownloaded: (file) {
            final sendPort = getSendPort();
            sendPort?.send(messages.FileDownloaded(file).map);
          });
          await receiver.listen();
          return exitBlock.future;
        case MyTasks.send:
          final senderMap = inputData!;
          final receiverPort = ReceivePort();
          IsolateNameServer.registerPortWithName(
              receiverPort.sendPort, PortName.main2sender.name);
          SendPort? getSendPort() =>
              IsolateNameServer.lookupPortByName(MyTasks.send.name);
          receiverPort.listen((message) {
            if (message["data"] == messages.MessageType.alive) {
              //TODO: Test alive feature
              log("Got alive message.", name: "Sender worker");
              getSendPort()?.send(const messages.Alive().map);
            }
          });
          final fileDirs = <String>[];
          for (var a = 0; senderMap["file$a"] != null; a++) {
            fileDirs.add(senderMap["file$a"]);
          }
          assert(fileDirs.isNotEmpty);
          final files = fileDirs.map((e) => File(e));
          final platformFiles = files.map((e) => PlatformFile(
              path: e.path, name: basename(e.path), size: e.lengthSync()));
          final device = Device.fromMap(senderMap);

          await Sender(
                  onUploadProgress: (percent) =>
                      getSendPort()?.send(messages.UpdatePercent(percent).map))
              .send(
            device,
            platformFiles,
            useDb: senderMap["useDb"],
          );
          getSendPort()?.send(const messages.Completed().map);
          return true;
      }
    } on Exception {
      rethrow;
    
  });
}

Future<ReceivePort> initialize() async {
  final port = ReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, MyTasks.send.name);
  await workManager.initialize(_callBack, isInDebugMode: kDebugMode);
  return port;
}
