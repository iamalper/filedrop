import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models.dart';

class DatabaseManager {
  bool _initalised = false;
  Future<Database> get _db {
    if (!_initalised && (Platform.isLinux || Platform.isWindows)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
    }
    _initalised = true;
    return openDatabase("files.db", version: 2, onCreate: (db, version) async {
      await db.execute(
          "create table downloaded (ID integer primary key autoincrement, name text not null, path text not null, type text, timeEpoch int not null)");
      await db.execute(
          "create table uploaded (ID integer primary key autoincrement, name text not null, path text not null, type text, timeEpoch int not null)");
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion == 1 && newVersion == 2) {
        await db
            .execute("alter table downloaded rename column time to timeEpoch");
        await db
            .execute("alter table uploaded rename column time to timeEpoch");
      } else {
        throw UnsupportedError("Unsupported db version");
      }
    });
  }

  ///Insert a uploaded or downloaded file information
  Future<void> insert(DbFile file) async {
    final db = await _db;
    switch (file.fileStatus) {
      case DbFileStatus.upload:
        await db.insert("uploaded", {
          "name": file.name,
          "timeEpoch": file.timeEpoch,
          "path": file.path
        });
        break;
      case DbFileStatus.download:
        await db.insert("downloaded", {
          "name": file.name,
          "timeEpoch": file.timeEpoch,
          "path": file.path
        });
        break;
    }
  }

  ///Delete all uploaded/downloaded file entries from database.
  ///
  ///Files will not be deleted. Only their infos will be deleted.
  Future<void> clear() async {
    final db = await _db;
    await Future.wait([db.delete("uploaded"), db.delete("downloaded")]);
  }

  ///Close the database.
  ///
  ///Another interaction with database will reopen the database.
  Future<void> close() async {
    final db = await _db;
    await db.close();
    _initalised = false;
  }

  ///Get all downloaded/uploaded file information as list.
  Future<List<DbFile>> get files async {
    final db = await _db;
    final uploadedMaps = await db
        .query("uploaded", columns: ["name", "type", "timeEpoch", "path"]);
    final uploadedFiles =
        uploadedMaps.map((e) => DbFile.uploadedFromMap(e)).toList();
    final downloadedMaps = await db
        .query("downloaded", columns: ["name", "type", "timeEpoch", "path"]);
    final downloadedFiles =
        downloadedMaps.map((e) => DbFile.downloadedFromMap(e)).toList();
    List<DbFile> files = [];
    files.addAll(uploadedFiles);
    files.addAll(downloadedFiles);
    return files;
  }
}
