import 'dart:async';
import 'dart:developer';
import 'package:flutter/animation.dart';
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
  static final _dio = Dio();
  static final _senderCancelToken = CancelToken();

  ///Pick files which are about to send.
  ///
  ///You should pass them to [send] method.
  static Future<List<PlatformFile>?> filePick() async {
    final result = await FilePicker.platform
        .pickFiles(withReadStream: true, allowMultiple: true);

    return result?.files;
  }

  static void cancel() {
    log("Request cancelled", name: "Sender");
    _senderCancelToken.cancel();
  }

  ///Sends file(s) to a device
  ///
  ///[files] will send to [device]
  ///
  ///If [uploadAnimC] is set, progess will be sent to it.
  ///
  ///If [useDb] is `true`, file informations will be saved to sqflite database.
  ///Must set to `false` for prevent database usage.
  ///
  ///Throws [OtherDeviceBusyException] if other device is busy.
  static Future<void> send(Device device, List<PlatformFile> files,
      {AnimationController? uploadAnimC, bool useDb = true}) async {
    final multiPartFiles = await Future.wait(files
        .map((e) =>
            http.MultipartFile.fromPath(e.name, e.path!, filename: e.name))
        .toList());
    final multipartRequest = http.MultipartRequest("POST", device.uri)
      ..files.addAll(multiPartFiles);
    uploadAnimC?.animateTo(Assets.uploadAnimStart);
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
        uploadAnimC?.animateTo(mappedValue.toDouble());
      }));
      uploadAnimC?.animateTo(1.0);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return;
      } else {
        rethrow;
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
      uploadAnimC?.value = 1;
      if (useDb) {
        await db.close();
      }
    }
  }
}
