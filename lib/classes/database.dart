import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
          "create table downloaded (ID integer primary key autoincrement, name text not null, path text not null, type text, timeepoch int not null)");
      await db.execute(
          "create table uploaded (ID integer primary key autoincrement, name text not null, path text not null, type text, timeepoch int not null)");
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion == 1 && newVersion == 2) {
        try {
          await db.execute(
              "alter table downloaded rename column time to timeepoch");
          await db
              .execute("alter table uploaded rename column time to timeepoch");
        } on Exception catch (e) {
          //Some old android devices does not support 'alert table'
          //Workaround: Dropping table then recreating
          //since database contains only file history that would not be a problem
          await FirebaseCrashlytics.instance.recordError(e, null,
              reason:
                  "Database version update $oldVersion to $newVersion failed.");
          await db.execute("drop table IF EXISTS downloaded");
          await db.execute("drop table IF EXISTS uploaded");
          await db.execute(
              "create table downloaded (ID integer primary key autoincrement, name text not null, path text not null, type text, timeepoch int not null)");
          await db.execute(
              "create table uploaded (ID integer primary key autoincrement, name text not null, path text not null, type text, timeepoch int not null)");
        }
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
          "timeepoch": file.timeEpoch,
          "path": file.path
        });
        break;
      case DbFileStatus.download:
        await db.insert("downloaded", {
          "name": file.name,
          "timeepoch": file.timeEpoch,
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
        .query("uploaded", columns: ["name", "type", "timeepoch", "path"]);
    final uploadedFiles =
        uploadedMaps.map((e) => DbFile.uploadedFromMap(e)).toList();
    final downloadedMaps = await db
        .query("downloaded", columns: ["name", "type", "timeepoch", "path"]);
    final downloadedFiles =
        downloadedMaps.map((e) => DbFile.downloadedFromMap(e)).toList();
    List<DbFile> files = [];
    files.addAll(uploadedFiles);
    files.addAll(downloadedFiles);
    return files;
  }
}
