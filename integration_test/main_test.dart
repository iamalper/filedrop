import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_sharer/classes/discover.dart';
import 'package:file_sharer/classes/send.dart';
import 'package:file_sharer/constants.dart';
import 'package:file_sharer/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_sharer/classes/receive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group("Ağ testleri", () {
    const testPort = Constants.port;
    late int code;
    late List<Device> devices;
    late List<File> gidenDosyalar;
    late String tempDir;
    setUpAll(() async {
      tempDir = (await getTemporaryDirectory()).path;
      gidenDosyalar = [
        File(path.join(tempDir, "deneme 1.txt")),
        File(path.join(tempDir, "deneme 2.txt"))
      ];
      for (var gidenDosya in gidenDosyalar) {
        gidenDosya.writeAsStringSync("deneme gövdesi",
            mode: FileMode.writeOnly);
      }

      code = await Receive.listen(port: testPort, ui: false, useDb: false);
      devices = await Discover.discover(port: testPort);
    });

    test('eşleşme', () async {
      final device = devices.where((device) => device.code == code);
      expect(device.length, equals(1));
    });
    test("tek dosya gönderim ve alma", () async {
      final gidenDosya = gidenDosyalar.first;
      final platfromFile = PlatformFile(
          readStream: gidenDosya.openRead(),
          size: gidenDosya.lengthSync(),
          name: path.basename(gidenDosya.path),
          path: gidenDosya.path);
      await Send.send(devices.single, [platfromFile], ui: false, useDb: false);
      expect(await gidenDosya.readAsBytes(),
          equals(File(files.single.path).readAsBytesSync()));
    });
    test("çoklu dosya gönderim ve alma", () async {
      final pFiles = List.generate(
          gidenDosyalar.length,
          (index) => PlatformFile(
              readStream: gidenDosyalar[index].openRead(),
              size: gidenDosyalar[index].lengthSync(),
              name: path.basename(gidenDosyalar[index].path),
              path: gidenDosyalar[index].path));
      await Send.send(devices.single, pFiles, ui: false, useDb: false);
      for (var i = 0; i < gidenDosyalar.length; i++) {
        final gidenDosya = gidenDosyalar[i];
        final gelenDosya = File(files[i].path);
        expect(gidenDosya.readAsBytesSync(), gelenDosya.readAsBytesSync());
      }
    });
    tearDown(() {
      for (var file in files) {
        File(file.path).deleteSync();
      }
      files = [];
    });
    tearDownAll(() async {
      await Receive.stopListening();
      for (var gidenDosya in gidenDosyalar) {
        gidenDosya.deleteSync();
      }
    });
  });
}
