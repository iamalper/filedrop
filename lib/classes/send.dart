import 'dart:async';
import 'dart:io';
import 'package:file_sharer/main.dart';
import 'package:file_sharer/models.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../screens/send_page.dart';
import 'database.dart';

late String filedir;

class _MyHttpOverrides extends HttpOverrides {}

class Send {
  static Future<List<PlatformFile>?> filePick() async {
    final result = await FilePicker.platform
        .pickFiles(withReadStream: true, allowMultiple: true);

    return result?.files;
  }

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
