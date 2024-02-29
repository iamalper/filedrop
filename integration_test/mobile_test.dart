import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:weepy/classes/discover.dart';
import 'package:weepy/models.dart';
import 'package:weepy/classes/workers/isolated_receiver.dart';
import 'package:weepy/classes/workers/isolated_sender.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var sendingFiles = <File>[];
  var platformFiles = <PlatformFile>[];
  var downloadedFiles = <DbFile>[];
  IsolatedReceiver? receiver;
  late Directory subdir;
  setUpAll(() async {
    final tempDir = await getTemporaryDirectory();
    subdir = tempDir.createTempSync("sending");
    final testImageData = await rootBundle.load("assets/test_image.png");
    final testImageFile = File(path.join(subdir.path, "test_image.png"));
    testImageFile.writeAsBytesSync(testImageData.buffer.asInt8List(),
        mode: FileMode.writeOnly);
    sendingFiles = [
      File(path.join(subdir.path, "deneme 1.txt")),
      File(path.join(subdir.path, "deneme 2.txt")),
      testImageFile
    ];
    for (var gidenDosya in sendingFiles) {
      if (path.extension(gidenDosya.path) == ".txt") {
        gidenDosya.writeAsStringSync("deneme gövdesi",
            mode: FileMode.writeOnly);
      }
    }
    platformFiles = List.generate(
        sendingFiles.length,
        (index) => PlatformFile(
            //readStream: sendingFiles[index].openRead(),
            size: sendingFiles[index].lengthSync(),
            name: path.basename(sendingFiles[index].path),
            path: sendingFiles[index].path));
  });

  final dbStatusVariant = ValueVariant({true, false});

  testWidgets("Test IsolatedReceiver & IsolatedSender", (_) async {
    receiver = IsolatedReceiver(
        saveToTemp: true,
        useDb: dbStatusVariant.currentValue!,
        onAllFilesDownloaded: (files) => downloadedFiles = files,
        onDownloadError: (error) => throw error,
        progressNotification: true);
    final code = await receiver!.listen();
    var allDevices = <Device>[];
    while (allDevices.isEmpty) {
      allDevices = await Discover.discover();
    }
    final devices = allDevices.where((device) => device.code == code);
    expect(devices, isNotEmpty, reason: "Expected to discover itself");
    await IsolatedSender().send(devices.first, platformFiles,
        useDb: dbStatusVariant.currentValue!);
    for (var i = 0; i < sendingFiles.length; i++) {
      final gidenDosya = sendingFiles[i];
      final gelenDosya = File(downloadedFiles[i].path);
      expect(gidenDosya.readAsBytesSync(), equals(gelenDosya.readAsBytesSync()),
          reason: "All sent files expected to has same content as originals");
    }
  }, variant: dbStatusVariant);
  tearDown(() {
    for (var file in downloadedFiles) {
      File(file.path).deleteSync();
    }
    downloadedFiles = [];
  });
  tearDownAll(() async {
    await receiver?.stop();
  });
}
