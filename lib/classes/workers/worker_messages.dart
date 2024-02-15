import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/models.dart';
import 'isolated_receiver.dart';
import 'isolated_sender.dart';

enum MessageType {
  updatePercent,
  filedropError,
  fileDownloaded,
  allFilesDownloaded,
  downloadStarted,
  completed,
  alive
}

///Message which should send between [IsolatedSender] and main isolate.
abstract class SenderMessage {
  final MessageType type;

  SenderMessage(this.type) {
    assert(MessageType.values[map["type"]] == type);
  }
  Map<String, dynamic> get map;
}

///Message which should send between [IsolatedReceiver] and main isolate.
abstract class ReceiverMessage {
  final MessageType type;
  ReceiverMessage(this.type) {
    assert(MessageType.values[map["type"]] == type);
  }
  Map<String, dynamic> get map;
}

///Sends when a progress updated.
///
///Read new percent from [newPercent]
class UpdatePercent implements SenderMessage, ReceiverMessage {
  ///The new percent of progress.
  ///
  ///It maybe same previous sent [newPercent] and it must between `0.00` and `1.00`
  final double newPercent;
  const UpdatePercent(this.newPercent);

  @override
  Map<String, dynamic> get map =>
      {"type": type.index, "newPercent": newPercent};

  @override
  final type = MessageType.updatePercent;

  UpdatePercent.fromMap(Map<String, dynamic> map)
      : newPercent = map["newPercent"] {
    assert(MessageType.values[map["type"]] == type);
  }
}

///Sends when an error caused from worker.
///
///Read error details from [exception.getErrorMessage(appLocalizations)]
class FiledropError implements SenderMessage, ReceiverMessage {
  final FileDropException exception;
  const FiledropError(this.exception);

  @override
  Map<String, dynamic> get map =>
      {"type": type.index, "exceptionType": exception.runtimeType};

  @override
  final type = MessageType.filedropError;

  FiledropError.fromMap(Map<String, dynamic> map)
      : exception = map["exceptionType"] {
    assert(MessageType.values[map["type"]] == type);
  }
}

class FileDownloaded implements ReceiverMessage {
  final DbFile file;
  const FileDownloaded(this.file);

  @override
  Map<String, dynamic> get map => {"type": type.index, "file": file.map};

  @override
  final type = MessageType.fileDownloaded;

  FileDownloaded.fromMap(Map<String, dynamic> map)
      : file = DbFile.fromMap(map["file"]) {
    assert(MessageType.values[map["type"]] == type);
  }
}

class AllFilesDownloaded implements ReceiverMessage {
  final List<DbFile> files;
  const AllFilesDownloaded(this.files);
  @override
  Map<String, dynamic> get map =>
      {"type": type.index, "files": files.map((e) => e.map).toList()};

  @override
  final type = MessageType.allFilesDownloaded;

  AllFilesDownloaded.fromMap(Map<String, dynamic> map)
      : files =
            (map["files"] as Iterable).map((e) => DbFile.fromMap(e)).toList() {
    assert(MessageType.values[map["type"]] == type);
  }
}

class DownloadStarted implements ReceiverMessage {
  const DownloadStarted();
  @override
  Map<String, dynamic> get map => {"type": type.index};

  @override
  final type = MessageType.downloadStarted;

  DownloadStarted.fromMap(Map<String, dynamic> map) {
    assert(MessageType.values[map["type"]] == type);
  }
}

///Sent when [IsolatedSender] completed uploading.
class Completed implements SenderMessage {
  const Completed();
  @override
  Map<String, dynamic> get map => {"type": type.index};

  @override
  MessageType get type => MessageType.completed;

  Completed.fromMap(Map<String, dynamic> map) {
    assert(MessageType.values[map["type"]] == type);
  }
}

///Respond for checking if worker is alive
class Alive implements SenderMessage, ReceiverMessage {
  const Alive();
  @override
  Map<String, dynamic> get map => {"type": type.index};

  @override
  MessageType get type => MessageType.alive;

  Alive.fromMap(Map<String, dynamic> map) {
    assert(MessageType.values[map["type"]] == type);
  }
}
