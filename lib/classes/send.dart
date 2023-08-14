import 'dart:async';
import 'dart:io';
import '../main.dart';
import '../models.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../screens/send_page.dart';
import 'database.dart';

class _MyHttpOverrides extends HttpOverrides {} //For using http apis from tests

///Class for all Sending jobs.
///
///Available methods are [filePick] and [send]
class Send {
  ///Pick files which are about to send.
  ///
  ///You should pass them to [send] method.
  static Future<List<PlatformFile>?> filePick() async {
    final result = await FilePicker.platform
        .pickFiles(withReadStream: true, allowMultiple: true);

    return result?.files;
  }

  ///Sends file(s) to a device
  ///
  ///[files] will send to [device]
  ///
  ///If [ui] is `true`, download progress will send to `UploadAnimC` from `send_page.dart`.
  ///Recieve page should be loaded before this method called.
  ///Set `false` for testing without loading `Receive` page, or a lateinit exception throws.
  ///
  ///If [useDb] is `true`, file informations will be saved to sqflite database.
  ///Must set to `false` for desktop enviroments because Sqflite isn't supported on desktops.
  ///
  ///Throws `http error` if other device is busy.
  static Future<void> send(Device device, List<PlatformFile> files,
      {bool ui = true, bool useDb = true}) async {
    HttpOverrides.global = _MyHttpOverrides();
    final requestMultiPart = http.MultipartRequest("POST", device.uri);
    for (var file in files) {
      requestMultiPart.files
          .add(await http.MultipartFile.fromPath(file.name, file.path!));
    }
    final requestStreamed = http.StreamedRequest("POST", device.uri);
    final byteStream = requestMultiPart.finalize();
    requestStreamed.contentLength = requestMultiPart.contentLength;
    requestStreamed.headers.addAll(requestMultiPart.headers);
    final totalBytesPer100 = requestMultiPart.contentLength / 100;
    int uploadedBytesTo100 = 0;
    await for (var bytes in byteStream) {
      requestStreamed.sink.add(bytes);
      if (ui) {
        uploadedBytesTo100 += bytes.length;
        if (uploadedBytesTo100 >= totalBytesPer100) {
          uploadAnimC.value += 0.01;
          uploadedBytesTo100 - totalBytesPer100;
        }
      }
    }
    requestStreamed.sink.close();
    final response = await requestStreamed.send();
    if (response.statusCode != 200) {
      throw "http error";
    } else {
      final db = DatabaseManager();
      if (useDb) {
        await db.open();
      }
      for (var file in files) {
        final mime = lookupMimeType(file.path!);
        final dbFile = DbFile(
            name: file.name,
            fileType: mime == null
                ? null
                : DbFileType.values
                    .singleWhere((element) => mime.startsWith(element.name)),
            fileStatus: DbFileStatus.upload,
            path: file.path!,
            time: DateTime.now());
        if (useDb) {
          await db.insert(dbFile);
        }
        allFiles.add(dbFile);
      }
      if (ui) {
        uploadAnimC.value = 1;
      }
      if (useDb) {
        await db.close();
      }
    }
  }
}
