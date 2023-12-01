import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/models.dart';

class SenderMessage {}

class ReceiverMessage {}

///Sends when a progress updated.
///
///Read new percent from [newPercent]
class UpdatePercent implements SenderMessage, ReceiverMessage {
  ///The new percent of progress.
  ///
  ///It maybe same previous sent [newPercent] and it must between `0.00` and `1.00`
  final double newPercent;
  const UpdatePercent(this.newPercent);
}

///Sends when an error caused from worker.
///
///Read error details from [exception.getErrorMessage(appLocalizations)]
class FiledropError implements SenderMessage, ReceiverMessage {
  final FileDropException exception;
  const FiledropError(this.exception);
}

class FileDownloaded implements ReceiverMessage {
  final DbFile file;
  const FileDownloaded(this.file);
}

class AllFilesDownloaded implements ReceiverMessage {
  final List<DbFile> files;
  const AllFilesDownloaded(this.files);
}

class DownloadStarted implements ReceiverMessage {
  const DownloadStarted();
}
