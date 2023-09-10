import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weepy/models.dart';
import 'classes/database.dart';

class _FilesNotifier extends AsyncNotifier<List<DbFile>> {
  final _db = DatabaseManager();
  @override
  Future<List<DbFile>> build() => _db.files;

  Future<void> clear() async {
    await _db.clear();
    await update((p0) {
      p0.clear();
      return p0;
    });
  }

  Future<void> add(DbFile file) async {
    await _db.insert(file);
    await update((p0) {
      p0.add(file);
      return p0;
    });
  }

  Future<void> addFiles(List<DbFile> files) async {
    for (var file in files) {
      await _db.insert(file);
    }
    await update((p0) {
      p0.addAll(files);
      return p0;
    });
  }
}

final filesProvider =
    AsyncNotifierProvider<_FilesNotifier, List<DbFile>>(_FilesNotifier.new);
