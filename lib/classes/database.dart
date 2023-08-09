import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models.dart';

class DatabaseManager {
  late Database _db;
  Future<void> open() async {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _db = await openDatabase(
      "files.db",
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
            "create table downloaded (ID integer primary key autoincrement, name text not null, path text not null, type text, time int not null)");
        await db.execute(
            "create table uploaded (ID integer primary key autoincrement, name text not null, path text not null, type text, time int not null)");
      },
    );
  }

  Future<void> insert(DbFile file) async {
    switch (file.fileStatus) {
      case DbFileStatus.upload:
        await _db.insert("uploaded", {
          "name": file.name,
          "type": file.fileType?.name,
          "time": file.timeEpoch,
          "path": file.path
        });
        break;
      case DbFileStatus.download:
        await _db.insert("downloaded", {
          "name": file.name,
          "type": file.fileType?.name,
          "time": file.timeEpoch,
          "path": file.path
        });
        break;
    }
  }

  Future<void> clear() async {
    await _db.delete("uploaded");
    await _db.delete("downloaded");
  }

  Future<void> close() async {
    await _db.close();
  }

  Future<List<DbFile>> get files async {
    final uploadedQueryResult =
        await _db.query("uploaded", columns: ["name", "type", "time", "path"]);
    final uploaded = List.generate(uploadedQueryResult.length, (index) {
      final rawdata = uploadedQueryResult[index];
      final type = rawdata["type"] as String?;
      return DbFile(
          name: rawdata["name"] as String,
          fileType: type == null
              ? null
              : DbFileType.values
                  .singleWhere((element) => element.name == type),
          time: DateTime.fromMillisecondsSinceEpoch(rawdata["time"] as int),
          path: rawdata["path"] as String,
          fileStatus: DbFileStatus.upload);
    });

    final downloadedQueryResult = await _db
        .query("downloaded", columns: ["name", "type", "time", "path"]);
    final downloaded = List.generate(downloadedQueryResult.length, (index) {
      final rawdata = downloadedQueryResult[index];
      final type = rawdata["type"] as String?;
      return DbFile(
          name: rawdata["name"] as String,
          fileType: type == null
              ? null
              : DbFileType.values
                  .singleWhere((element) => element.name == type),
          time: DateTime.fromMillisecondsSinceEpoch(rawdata["time"] as int),
          path: rawdata["path"] as String,
          fileStatus: DbFileStatus.download);
    });
    List<DbFile> files = [];
    files.addAll(uploaded);
    files.addAll(downloaded);
    return files;
  }
}
