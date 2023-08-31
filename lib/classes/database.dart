import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models.dart';

class DatabaseManager {
  late Database _db;

  ///Open the database and creates tables if didn't created before.
  ///
  ///Is is safe to reopen database after [close] called.
  ///
  ///It didn't enough tested for desktop platforms.
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

  ///Insert a uploaded or downloaded file information
  ///
  ///Make sure [open] is called and [close] isn't called.
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

  ///Delete all uploaded/downloaded file entries from database.
  ///
  ///Files will not be deleted. Only their infos will be deleted.
  ///
  ///Make sure [open] is called and [close] isn't called.
  Future<void> clear() =>
      Future.wait([_db.delete("uploaded"), _db.delete("downloaded")]);

  ///Close the database.
  ///
  ///If database is not opened, lateinit exception throws.
  Future<void> close() => _db.close();

  ///Get all donwloaded/uploaded file information as list.
  ///
  ///Make sure [open] is called and [close] isn't called.
  Future<List<DbFile>> get files async {
    final uploadedMaps =
        await _db.query("uploaded", columns: ["name", "type", "time", "path"]);
    final uploadedFiles =
        uploadedMaps.map((e) => DbFile.uploadedFromMap(e)).toList();
    final downloadedMaps = await _db
        .query("downloaded", columns: ["name", "type", "time", "path"]);
    final downloadedFiles =
        downloadedMaps.map((e) => DbFile.downloadedFromMap(e)).toList();
    List<DbFile> files = [];
    files.addAll(uploadedFiles);
    files.addAll(downloadedFiles);
    return files;
  }
}
