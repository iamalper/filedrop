import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:weepy/classes/discover.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/classes/sender.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weepy/classes/receiver.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:weepy/models.dart';
import 'fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var sendingFiles = <File>[];
  var downloadedFiles = <DbFile>[];
  PathProviderPlatform.instance = FakePathProviderPlatform();
  HttpOverrides.global = _MyHttpOverrides();
  final recieve = Receiver(
      saveToTemp: true,
      useDb: false,
      onAllFilesDownloaded: (files) => downloadedFiles = files);

  setUpAll(() async {
    final tempDir = (await getTemporaryDirectory()).path;
    sendingFiles = [
      File(path.join(tempDir, "deneme 1.txt")),
      File(path.join(tempDir, "deneme 2.txt"))
    ];
    for (var gidenDosya in sendingFiles) {
      gidenDosya.writeAsStringSync("deneme gövdesi", mode: FileMode.writeOnly);
    }
  });

  test('Discover, send and receive files', () async {
    final code = await recieve.listen();
    final allDevices = await Discover.discover();
    final device = allDevices.where((device) => device.code == code);
    expect(device, hasLength(1), reason: "Expected to discover itself");
    final pFiles = List.generate(
        sendingFiles.length,
        (index) => PlatformFile(
            readStream: sendingFiles[index].openRead(),
            size: sendingFiles[index].lengthSync(),
            name: path.basename(sendingFiles[index].path),
            path: sendingFiles[index].path));
    await Sender.send(device.single, pFiles, useDb: false);
    for (var i = 0; i < sendingFiles.length; i++) {
      final gidenDosya = sendingFiles[i];
      final gelenDosya = File(downloadedFiles[i].path);
      expect(gidenDosya.readAsBytesSync(), gelenDosya.readAsBytesSync(),
          reason: "All sent files expected to has same content as originals");
    }
  });

  test("Error handling", () async {
    expect(
        Sender.send(
            Device(adress: await Discover.getMyIp(), code: 1000),
            [
              PlatformFile(
                  readStream: sendingFiles[1].openRead(),
                  size: sendingFiles[1].lengthSync(),
                  name: path.basename(sendingFiles[1].path),
                  path: sendingFiles[1].path),
            ],
            useDb: false),
        throwsA(isA<ConnectionLostException>()));
  });
  tearDown(() {
    for (var file in downloadedFiles) {
      File(file.path).deleteSync();
    }
    downloadedFiles = [];
  });
  tearDownAll(() async {
    await recieve.stopListening();
    for (var sentFile in sendingFiles) {
      sentFile.deleteSync();
    }
  });
}

class _MyHttpOverrides extends HttpOverrides {} //For using http apis from tests