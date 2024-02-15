import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/constants.dart';
import '../models.dart';
import 'package:file_picker/file_picker.dart';
import 'database.dart';
import 'package:num_remap/num_remap.dart';
import 'package:http/http.dart' as http;

///Class for all Sending jobs.
///
///Available methods are [filePick] and [send]
class Sender {
  final _dio = Dio();
  final _senderCancelToken = CancelToken();
  final void Function(double percent)? onUploadProgress;
  Sender({this.onUploadProgress});

  ///Pick files which are about to send.
  ///
  ///You should pass them to [send] method.
  Future<List<PlatformFile>?> filePick() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    return result?.files;
  }

  void cancel() {
    log("Request cancelled", name: "Sender");
    _senderCancelToken.cancel();
  }

  ///Sends file(s) to a device
  ///
  ///[files] will send to [device]
  ///
  ///If [onUploadProgress] is set, progress will be sent to it.
  ///
  ///If [useDb] is `true`, file information will be saved to sqflite database.
  ///Must set to `false` for prevent database usage.
  ///
  ///Throws [OtherDeviceBusyException] if other device is busy.
  Future<void> send(
    Device device,
    Iterable<PlatformFile> files, {
    bool useDb = true,
  }) async {
    final multiPartFiles = await Future.wait(files.map((e) async {
      final readStream = e.readStream;
      if (readStream == null) {
        return await http.MultipartFile.fromPath(e.name, e.path!,
            filename: e.name);
      } else {
        return http.MultipartFile(e.name, readStream, e.size, filename: e.name);
      }
    }).toList());
    final multipartRequest = http.MultipartRequest("POST", device.uri)
      ..files.addAll(multiPartFiles);
    final multipartStream = multipartRequest.finalize();
    final headers = <String, dynamic>{
      Headers.contentLengthHeader: multipartRequest.contentLength,
    }..addAll(multipartRequest.headers);
    final Response<void> response;
    try {
      response = await _dio.postUri<void>(device.uri,
          data: multipartStream,
          cancelToken: _senderCancelToken,
          options: Options(
            headers: headers,
          ), onSendProgress: ((count, total) {
        log("Progress $total/$count", name: "Sender");
        final newValue = count / total;
        assert(newValue <= 1.0 && newValue >= 0.0);
        final mappedValue = newValue.remapAndClamp(
            0.0, 1.0, Assets.uploadAnimStart, Assets.uploadAnimEnd);
        assert(mappedValue <= Assets.uploadAnimEnd &&
            mappedValue >= Assets.uploadAnimStart);
        onUploadProgress?.call(newValue);
      }));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return;
      } else {
        throw ConnectionLostException();
      }
    }
    if (response.statusCode != 200) {
      throw OtherDeviceBusyException();
    } else {
      final db = DatabaseManager();
      for (var file in files) {
        final dbFile = DbFile(
            name: file.name,
            fileStatus: DbFileStatus.upload,
            path: file.path!,
            time: DateTime.now());
        if (useDb) {
          await db.insert(dbFile);
        }
      }
      if (useDb) {
        await db.close();
      }
    }
  }
}
