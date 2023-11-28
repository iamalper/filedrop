import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

enum DbFileType { image, video, audio, text }

enum DbFileStatus { upload, download }

class DbFile {
  ///name of the file with extension.
  final String name;

  ///"Status" of the file. Should set `upload` if file sent or `download` if file got.
  final DbFileStatus fileStatus;

  ///It is full path of the file. It's using to open the file.
  final String path;

  ///It is the time when the file operation is completed.
  final DateTime time;

  ///Sent or recieved files must saved to or load from database with this model.
  ///
  ///[name] is name of the file with extension.
  ///
  ///[fileStatus] should set `upload` if file sent or `download` if file got.
  ///
  ///[path] is full path of the file. It's using to open the file.
  ///
  ///[time] is the time when file operation is completed.
  const DbFile(
      {required this.name,
      required this.path,
      required this.time,
      required this.fileStatus});

  ///Use this constructor for load an uploaded file infos from database.
  DbFile.uploadedFromMap(Map<String, dynamic> map)
      : name = map["name"],
        fileStatus = DbFileStatus.upload,
        time = DateTime.fromMillisecondsSinceEpoch(map["time"]),
        path = map["path"];

  ///Use this constructor for load an downloaded file infos from database.
  DbFile.downloadedFromMap(Map<String, dynamic> map)
      : name = map["name"],
        fileStatus = DbFileStatus.download,
        time = DateTime.fromMillisecondsSinceEpoch(map["time"]),
        path = map["path"];

  ///Icon for showing in UI.
  ///It is download or upload icon.
  ///
  ///Is's generated based on [fileStatus]
  Icon get icon {
    switch (fileStatus) {
      case DbFileStatus.download:
        return const Icon(Icons.download);
      case DbFileStatus.upload:
        return const Icon(Icons.upload);
    }
  }

  ///Milisecons since Epoch of [time]
  ///It is independent from time zone.
  int get timeEpoch => time.millisecondsSinceEpoch;

  ///Open the file in OS
  Future<void> open() => OpenFilex.open(path);

  ///dbFile{name: [name], fileType: [fileType].name, time: [time], fileStatus: [fileStatus].name}
  @override
  String toString() =>
      "dbFile{name: $name, time: $time, fileStatus: ${fileStatus.name}}";
}

class Device {
  ///The ip adress of the device without port number
  final String adress;

  ///The code returned from target device. Users should
  ///see same code on each devices.
  final int code;

  ///Port number of device. Should not set unless testing.
  final int port;

  ///A device discovered after searching network
  ///
  ///[adress] is the ip adress of the device without port number
  ///
  ///[code] is the code returned from target device. Users should
  ///see same code each devices.
  ///
  ///[port] is the port number of device. Should not set unless testing.
  const Device({required this.adress, required this.code, required this.port});

  ///Uri object for device.
  ///
  ///Throws `ip error` if it can't parse ip adress and port but normally it should.
  Uri get uri {
    try {
      return Uri.http("$adress:$port");
    } catch (_) {
      throw "ip error";
    }
  }

  Map<String, dynamic> get map =>
      {"adress": adress, "code": code, "port": port};

  Device.fromMap(Map<String, dynamic> map)
      : adress = map["adress"],
        code = map["code"],
        port = map["port"];

  ///deviceModel{Adress: [adress], Code: [code], Port: [port]}
  @override
  String toString() =>
      "Device Model{Adress: $adress, Code: $code, Port: $port}";
}
