import 'package:file_sharer/constants.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

enum DbFileType { image, video, audio, text }

enum DbFileStatus { upload, download }

class DbFile {
  String name;
  DbFileStatus fileStatus;
  DbFileType? fileType;
  String path;
  late final Icon icon;
  DateTime time;
  DbFile(
      {required this.name,
      this.fileType,
      required this.path,
      required this.time,
      required this.fileStatus}) {
    switch (fileStatus) {
      case DbFileStatus.download:
        icon = const Icon(Icons.download);
        break;
      case DbFileStatus.upload:
        icon = const Icon(Icons.upload);
        break;
    }
  }
  int get timeEpoch => time.millisecondsSinceEpoch;

  void open() => OpenFilex.open(path);
}

class Device {
  final String adress;
  final int code;
  int port;
  Device(
      {required this.adress, required this.code, this.port = Constants.port});
  Uri get uri {
    try {
      return Uri.http("$adress:$port");
    } catch (_) {
      throw "ip error";
    }
  }
}
