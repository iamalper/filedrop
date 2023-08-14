import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:weepy/classes/discover.dart';
import 'package:weepy/classes/send.dart';
import 'package:weepy/constants.dart';
import 'package:weepy/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weepy/classes/receive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group("Network tests", () {
    const testPort = Constants.port;
    late int code;
    late List<Device> devices;
    late List<File> sendingFiles;
    late String tempDir;
    setUpAll(() async {
      tempDir = (await getTemporaryDirectory()).path;
      sendingFiles = [
        File(path.join(tempDir, "deneme 1.txt")),
        File(path.join(tempDir, "deneme 2.txt"))
      ];
      for (var gidenDosya in sendingFiles) {
        gidenDosya.writeAsStringSync("deneme gövdesi",
            mode: FileMode.writeOnly);
      }

      code =
          await Receive.listen(port: testPort, saveToTemp: true, useDb: false);
      devices = await Discover.discover(port: testPort);
    });

    test('discover', () async {
      final device = devices.where((device) => device.code == code);
      expect(device.length, equals(1));
    });
    test("single file send and recieve", () async {
      final sendingFile = sendingFiles.first;
      final platfromFile = PlatformFile(
          readStream: sendingFile.openRead(),
          size: sendingFile.lengthSync(),
          name: path.basename(sendingFile.path),
          path: sendingFile.path);
      await Send.send(devices.single, [platfromFile], useDb: false);
      expect(await sendingFile.readAsBytes(),
          equals(File(Receive.files.single.path).readAsBytesSync()));
    });
    test("multi file send and recieve", () async {
      final pFiles = List.generate(
          sendingFiles.length,
          (index) => PlatformFile(
              readStream: sendingFiles[index].openRead(),
              size: sendingFiles[index].lengthSync(),
              name: path.basename(sendingFiles[index].path),
              path: sendingFiles[index].path));
      await Send.send(devices.single, pFiles, useDb: false);
      for (var i = 0; i < sendingFiles.length; i++) {
        final gidenDosya = sendingFiles[i];
        final gelenDosya = File(Receive.files[i].path);
        expect(gidenDosya.readAsBytesSync(), gelenDosya.readAsBytesSync());
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
  });
}
