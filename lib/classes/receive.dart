import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:path/path.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../screens/receive_page.dart' show downloadAnimC;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database.dart';
import 'package:file_sharer/models.dart';
import '../constants.dart';
import 'discover.dart';
import '../main.dart';

HttpServer? _server;
List<DbFile> files = [];
final _ms = MediaStore();
late String _tempDir;
late int _code;

class Receive {
  static Future<int> listen(
      {int port = Constants.port, bool ui = true, bool useDb = true}) async {
    if ((Platform.isAndroid || Platform.isIOS) && ui) {
      final perm = await Permission.storage.request();
      if (!perm.isGranted) throw "Permission denied";
    }
    final ip = await Discover.getMyIp();
    _code = Random().nextInt(8888) + 1111;
    MediaStore.appFolder = Constants.saveFolder;
    _tempDir = (await getTemporaryDirectory()).path;
    bool isBusy = false;
    _server = await shelf.serve((Request request) async {
      if (isBusy) {
        //Halihazırda işlem yapılıyorsa yeni bağlantıları reddet
        return Response.forbidden(null);
      }
      if (request.method == "GET") {
        //kendini tanıtma
        return Response.ok(
            jsonEncode({"mesaj": Constants.tanitim, "code": _code}));
      } else if (request.method == "POST") {
        //dosya al
        try {
          isBusy = true;
          final stream = MimeMultipartTransformer(
                  MediaType.parse(request.headers['content-type']!)
                      .parameters["boundary"]!)
              .bind(request.read());

          final db = DatabaseManager();
          if (useDb) {
            await db.open();
          }
          await for (var mime in stream) {
            String filename =
                HeaderValue.parse(mime.headers['content-disposition']!)
                    .parameters["filename"]!;
            late File file;
            if ((Platform.isLinux || Platform.isWindows) && ui) {
              //Direk indirilenlere kayıt
              final dir = Directory(join(
                  (await getDownloadsDirectory())!.path, Constants.saveFolder));
              dir.createSync();

              file = File(join(dir.path, filename));
              for (var i = 1; file.existsSync(); i++) {
                final name = basenameWithoutExtension(file.path);
                final exten = extension(file.path);
                file = File(join(dir.path, "$name ($i)$exten"));
              }
            } else {
              //Mobilde MediaStore sdk için ve test için temp klasörüne kayıt
              file = File(join(_tempDir, filename));
              for (var i = 1; file.existsSync(); i++) {
                final name = basenameWithoutExtension(file.path);
                final exten = extension(file.path);
                file = File(join(_tempDir, "$name ($i)$exten"));
              }
              if (file.existsSync()) {
                file.deleteSync();
              }
            }
            final totalBytesPer100 = request.contentLength! / 100;
            int downloadedBytesto100 = 0;
            await for (var bytes in mime) {
              file.writeAsBytesSync(bytes, mode: FileMode.writeOnlyAppend);
              if (ui) {
                downloadedBytesto100 += bytes.length;
                if (downloadedBytesto100 >= totalBytesPer100) {
                  downloadAnimC.value += 0.01;
                  downloadedBytesto100 - totalBytesPer100;
                }
              }
            }
            final mimeType = lookupMimeType(file.path);
            late bool isSaved;
            if ((Platform.isLinux || Platform.isWindows) && ui) {
              //masaüstünde direk kaydedildi
              isSaved = true;
            } else if (ui) {
              //mobil için mediastore apisi kullanılıyor
              isSaved = await _ms.saveFile(
                  tempFilePath: file.path,
                  dirType: DirType.download,
                  dirName: DirName.download);
            } else {
              //test için
              isSaved = true;
            }
            if (isSaved) {
              String? type;
              if (mimeType != null) {
                if (mimeType.startsWith("image/")) {
                  type = "image";
                } else if (mimeType.startsWith("audio/")) {
                  type = "audio";
                } else if (mimeType.startsWith("video/")) {
                  type = "video";
                }
              }
              final dbFile = DbFile(
                  name: filename,
                  time: DateTime.now(),
                  fileStatus: DbFileStatus.download,
                  fileType: type == null
                      ? null
                      : DbFileType.values
                          .singleWhere((element) => element.name == type),
                  path: file.path);
              files.add(dbFile);
              if (useDb) {
                await db.insert(dbFile);
              }
              allFiles.add(dbFile);
            }
          }
          if (useDb) {
            await db.close();
          }
          return Response.ok(null);
        } catch (e) {
          rethrow;
        } finally {
          if (ui) {
            downloadAnimC.value = 1;
          }
          isBusy = false;
        }
      }
      return Response.badRequest();
    }, ip, port, poweredByHeader: null);

    return _code;
  }

  static Future<void> stopListening() async => await _server?.close();
}
