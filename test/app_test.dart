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
  HttpOverrides.global = _MyHttpOverrides();
  PathProviderPlatform.instance = FakePathProviderPlatform();

  var sendingFiles = <File>[];
  var platformFiles = <PlatformFile>[];
  late Directory subdir;
  setUpAll(() async {
    final tempDir = await getTemporaryDirectory();
    subdir = tempDir.createTempSync("sending");
    sendingFiles = [
      File(path.join(tempDir.path, subdir.path, "deneme 1.txt")),
      File(path.join(tempDir.path, subdir.path, "deneme 2.txt")),
      File("test/test_image.png"),
    ];
    for (var gidenDosya in sendingFiles) {
      if (!gidenDosya.existsSync()) {
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
  group('IO tests', () {
    var downloadedFiles = <DbFile>[];
    final recieve = Receiver(
        saveToTemp: true,
        useDb: false,
        onAllFilesDownloaded: (files) => downloadedFiles = files);

    test('Discover, send and receive files', () async {
      final code = await recieve.listen();
      var allDevices = <Device>[];
      while (allDevices.isEmpty) {
        allDevices = await Discover.discover();
      }
      final devices = allDevices.where((device) => device.code == code);
      expect(devices, isNotEmpty, reason: "Expected to discover itself");
      await Sender.send(devices.first, platformFiles, useDb: false);
      for (var i = 0; i < sendingFiles.length; i++) {
        final gidenDosya = sendingFiles[i];
        final gelenDosya = File(downloadedFiles[i].path);
        expect(
            gidenDosya.readAsBytesSync(), equals(gelenDosya.readAsBytesSync()),
            reason: "All sent files expected to has same content as originals");
      }
    }, timeout: const Timeout(Duration(seconds: 20)));

    tearDown(() {
      for (var file in downloadedFiles) {
        File(file.path).deleteSync();
      }
      downloadedFiles = [];
    });
    tearDownAll(() async {
      await recieve.stopListening();
    });
  });

  group('Error handling', () {
    test(
      "Handle no_receiver error",
      () async {
        final sendFuture = Sender.send(
            const Device(adress: "192.168.9.9", code: 1000, port: 2326),
            platformFiles,
            useDb: false);
        expect(sendFuture, throwsA(isA<FileDropException>()));
      },
    );
    test("Handle connection lost while reciving", () async {
      FileDropException? throwedError;
      final code = await Receiver(
              onDownloadError: (error) => throwedError = error, useDb: false)
          .listen();
      var devices = <Device>[];
      while (devices.isEmpty) {
        devices = await Discover.discover();
      }
      expect(devices.where((device) => device.code == code), isNotEmpty);
      Future.delayed(const Duration(milliseconds: 500), Sender.cancel);
      await Sender.send(
          devices.first,
          [
            PlatformFile(
                name: "testt",
                size: 1000000000000000000,
                path: platformFiles[1].path,
                readStream: Stream.periodic(const Duration(milliseconds: 10),
                    (_) => List.filled(1024, 0)))
          ],
          useDb: false);
      await Future.delayed(const Duration(seconds: 15));
      expect(throwedError, isNotNull);
    }, timeout: const Timeout(Duration(minutes: 1, seconds: 15)));
  });
  tearDownAll(() => subdir.deleteSync(recursive: true));
}

class _MyHttpOverrides extends HttpOverrides {} //For using http apis from tests