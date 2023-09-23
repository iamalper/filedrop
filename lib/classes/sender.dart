import 'dart:async';
import 'package:flutter/animation.dart';
import 'package:dio/dio.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/constants.dart';
import '../models.dart';
import 'package:file_picker/file_picker.dart';
import 'database.dart';
import 'package:num_remap/num_remap.dart';

///Class for all Sending jobs.
///
///Available methods are [filePick] and [send]
class Sender {
  static final _dio = Dio();

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
  ///If [uploadAnimC] is set, progess will be sent to it.
  ///
  ///If [useDb] is `true`, file informations will be saved to sqflite database.
  ///Must set to `false` for prevent database usage.
  ///
  ///Throws [OtherDeviceBusyException] if other device is busy.
  static Future<void> send(Device device, List<PlatformFile> files,
      {AnimationController? uploadAnimC, bool useDb = true}) async {
    final formData = FormData.fromMap({
      'files': files
          .map((e) => MultipartFile.fromFileSync(e.path!, filename: e.name))
          .toList(),
    });
    uploadAnimC?.animateTo(Assets.uploadAnimStart);
    final Response<void> response;
    try {
      response = await _dio.post<void>(device.uri.toString(),
          data: formData,
          options: Options(
            headers: {
              Headers.contentLengthHeader: formData.length,
            },
          ), onSendProgress: ((count, total) {
        final newValue = count / total;
        assert(newValue <= 1.0 && newValue >= 0.0);
        final mappedValue = newValue.remapAndClamp(
            0.0, 1.0, Assets.uploadAnimStart, Assets.uploadAnimEnd);
        assert(mappedValue <= Assets.uploadAnimEnd &&
            mappedValue >= Assets.uploadAnimStart);
        uploadAnimC?.animateTo(mappedValue.toDouble());
      }));
      uploadAnimC?.animateTo(1.0);
    } catch (_) {
      throw ConnectionLostException();
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
