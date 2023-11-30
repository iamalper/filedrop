import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:path/path.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:weepy/classes/exceptions.dart';
import 'database.dart';
import '../models.dart';
import '../constants.dart';

///Class for all Recieve jobs
///
///Available methods are [listen] and [stopListening]
class Receiver {
  final _files = <DbFile>[];
  late MediaStore _ms;
  final _tempDir = getTemporaryDirectory();
  final int _code;
  HttpServer? _server;
  bool _isBusy = false;
  int get code => _code;

  ///If [useDb] is `true`, file informations will be saved to sqflite database.
  ///Don't needed to open the database manually.
  final bool useDb;

  ///If [saveToTemp] is `true`, files will be saved to temp directory. It's useful for
  ///testing because don't need for storage permissions
  final bool saveToTemp;

  ///If [downloadAnimC] is set, progress will be sent to it.
  @Deprecated(
      "Prefer downloadUpdatePercent() because it allows updating UI from isolates")
  final AnimationController? downloadAnimC;

  ///[onDownloadUpdatePercent] will be called for each saved chunk in download operation.
  ///
  ///Use for animating progress.
  final void Function(double percent)? onDownloadUpdatePercent;

  ///[port] listened for incoming connections. Should not set except testing or
  ///other devices will require manual port setting.
  final int? port;

  ///[onDownloadStart] will be called when starting to download first time.
  final void Function()? onDownloadStart;

  ///[onFileDownloaded] will be called when a file downloaded succesfully.
  final void Function(DbFile file)? onFileDownloaded;

  ///[onAllFilesDownloaded] will be called when all files succesfully downloaded.
  final void Function(List<DbFile> files)? onAllFilesDownloaded;

  ///[onDownloadError] will be called when error happened while saving file.
  ///
  ///When [onDownloadError] called, no other callback will be called,
  ///no exception thrown and server will wait new connection.
  ///
  ///See [FileDropException]
  final void Function(FileDropException error)? onDownloadError;

  ///Listen and receive files from other devices.
  ///
  ///Set [onDownloadUpdatePercent], [onDownloadStart], [onFileDownloaded], [onAllFilesDownloaded] for animating download progess.
  ///
  ///Call [listen] for start listening.
  Receiver({
    this.downloadAnimC,
    this.onDownloadUpdatePercent,
    this.useDb = true,
    this.saveToTemp = false,
    this.port,
    this.onDownloadStart,
    this.onFileDownloaded,
    this.onAllFilesDownloaded,
    this.onDownloadError,
    int? code,
  }) : _code = code ?? Random().nextInt(8888) + 1111;

  ///Get storage permission for Android and IOS
  ///
  ///For other platforms always returns [true]
  Future<bool> checkPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      //These platforms needs storage permissions (only tested on Android)
      final perm = await Permission.storage.request();
      return perm.isGranted;
    } else {
      return true;
    }
  }

  ///Starts listening for discovery and recieving file(s).
  ///Handles one connection at once. If another device tires to match,
  ///sends `400 Bad request` as response
  ///
  ///Returns the code generated for discovery. Other devices should select this code for
  ///connecting to this device
  Future<int> listen() async {
    if (!saveToTemp) {
      final permissionStatus = await checkPermission();
      if (!permissionStatus) {
        throw NoStoragePermissionException();
      }
      if (Platform.isAndroid) {
        _ms = MediaStore();
        MediaStore.appFolder = Constants.saveFolder;
      }
    }
    _isBusy = false;

    for (var port = Constants.minPort; port <= Constants.maxPort; port++) {
      try {
        _server = await shelf.serve(
            _requestMethod, InternetAddress.anyIPv4, port,
            poweredByHeader: null);
        break;
      } on SocketException catch (_) {
        if (port < Constants.maxPort) {
          continue;
        } else {
          onDownloadError?.call(ConnectionLostException());
        }
      }
    }
    if (_server != null) {
      log("Listening for new file with port: ${_server!.port}, code: $_code",
          name: "Receive");
    }
    return _code;
  }

  Future<Response> _requestMethod(Request request) async {
    if (_isBusy) {
      //Deny new connections if busy
      log("Connection denied, because busy", name: "Receive server");
      return Response.forbidden(null);
    }
    if (request.method == "GET") {
      //Response to discovery requests
      log("Discovery request recieved, returned code $_code",
          name: "Receive server");
      return Response.ok(
          jsonEncode({"message": Constants.meeting, "code": _code}));
    } else if (request.method == "POST") {
      //Reciving file
      log("Reciving file...", name: "Receive server");
      try {
        _isBusy = true;
        final byteStream = request.read();
        final stream = MimeMultipartTransformer(
                MediaType.parse(request.headers['content-type']!)
                    .parameters["boundary"]!)
            .bind(byteStream);
        onDownloadStart?.call();
        final db = DatabaseManager();
        await for (var mime in stream) {
          final filename =
              HeaderValue.parse(mime.headers['content-disposition']!)
                  .parameters["filename"]!;
          File file;
          if ((Platform.isLinux || Platform.isWindows) && !saveToTemp) {
            //Saving to downloads because these platforms don't require any permission
            final dir = Directory(join(
                (await getDownloadsDirectory())!.path, Constants.saveFolder));
            dir.createSync();

            file = File(join(dir.path, filename));
            file = _generateFileName(file, dir);
          } else {
            //Saving to the temp folder for mediastore or testing
            file = File(join((await _tempDir).path, filename));
            file = _generateFileName(file, await _tempDir);
          }
          final totalLengh = request.contentLength!;
          final fileWriter = file.openWrite();
          var downloadPercent = 0.0;
          await for (var bytes in mime.timeout(const Duration(seconds: 10))) {
            fileWriter.add(bytes);
            downloadPercent += bytes.length / totalLengh;
            downloadAnimC?.value = downloadPercent;
            onDownloadUpdatePercent?.call(downloadPercent);
          }
          await fileWriter.flush();
          await fileWriter.close();
          final dbFile = DbFile(
              name: filename,
              time: DateTime.now(),
              fileStatus: DbFileStatus.download,
              path: file.path);
          final bool isSaved;
          if ((Platform.isLinux || Platform.isWindows) || saveToTemp) {
            //Skipping Media Store confirmation for desktop platforms or saving to temp folder
            isSaved = true;
          } else {
            //Using Media Store for mobile platforms
            isSaved = await _ms.saveFile(
                tempFilePath: file.path,
                dirType: DirType.download,
                dirName: DirName.download);
          }
          if (isSaved) {
            _files.add(dbFile);
            onFileDownloaded?.call(dbFile);
            if (useDb) {
              await db.insert(dbFile);
            }
          } else {
            throw FileCouldntSavedException(dbFile);
          }
        }
        onAllFilesDownloaded?.call(_files);
        if (useDb) {
          await db.close();
        }
        log("Recived file(s) $_files", name: "Receive server");
        return Response.ok(null);
      } catch (_) {
        log("Download error", name: "Receiver");
        onDownloadError?.call(ConnectionLostException());
        return Response.badRequest();
      } finally {
        //File downloaded successfully or failed. Resetting progess for both cases.
        downloadAnimC?.value = 1;

        //Open for new connections
        _isBusy = false;
      }
    } else {
      //Request method neither POST or GET
      log("Invalid request recieved", name: "Receive server");
      return Response.badRequest();
    }
  }

  ///Ensures a file with same name not exists.
  ///
  ///It may rename files as file.exe to file (1).exe
  static File _generateFileName(File file, Directory dir) {
    for (var i = 1; file.existsSync(); i++) {
      final name = basenameWithoutExtension(file.path);
      final exten = extension(file.path);
      file = File(join(dir.path, "$name ($i)$exten"));
    }
    return file;
  }

  ///Closes the listening server.
  ///
  ///Is is safe to call before [listen] or after [listen] .
  Future<void> stopListening() async => await _server?.close();

  Map<String, dynamic> get map => {
        "useDb": useDb,
        "saveToTemp": saveToTemp,
        "port": port,
        "code": _code,
      };

  Receiver.fromMap(Map<String, dynamic> map)
      : this(
            useDb: map["useDb"],
            saveToTemp: map["saveToTemp"],
            port: map["port"],
            code: map["code"]);
}
