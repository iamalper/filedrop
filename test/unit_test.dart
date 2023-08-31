import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:weepy/classes/discover.dart';
import 'package:weepy/classes/send.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weepy/classes/receive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  List<File> sendingFiles = [];
  setUpAll(() async {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    HttpOverrides.global = _MyHttpOverrides();
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
    final code = await Receive.listen(saveToTemp: true, useDb: false);
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
    await Send.send(device.single, pFiles, useDb: false);
    for (var i = 0; i < sendingFiles.length; i++) {
      final gidenDosya = sendingFiles[i];
      final gelenDosya = File(Receive.files[i].path);
      expect(gidenDosya.readAsBytesSync(), gelenDosya.readAsBytesSync(),
          reason: "All sent files expected to has same content as originals");
    }
  });

  tearDown(() {
    for (var file in Receive.files) {
      File(file.path).deleteSync();
    }
    Receive.files = [];
  });
  tearDownAll(() async {
    await Receive.stopListening();
    for (var sentFile in sendingFiles) {
      sentFile.deleteSync();
    }
  });
}

class _MyHttpOverrides extends HttpOverrides {} //For using http apis from tests