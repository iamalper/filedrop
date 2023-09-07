import 'package:weepy/models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

///Base class for FileDrop exceptions.
///
///Has [getErrorMessage] method for localised error messages.
abstract class FileDropException implements Exception {
  String getErrorMessage(AppLocalizations appLocalizations);
}

///Throw when a downloaded file couldn't moved from temp folder to storage
///
///Use [getErrorMessage] for localised error message.
///
///Usually throws when device has no enough storage space.
class FileCouldntSavedException implements FileDropException {
  final DbFile file;
  FileCouldntSavedException(this.file);

  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.fileCoulntSaved;
}

///Throws when can't get its own ip adress.
///
///Use [getErrorMessage] for localised error message.
///
///Usually throws when don't connected to a network.
class IpException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.notConnectedToNetwork;
}

class ConnectionLostException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) {
    // TODO: implement getErrorMessage
    throw UnimplementedError();
  }
}

///Throws when storage permission request rejected by user.
///
///Use [getErrorMessage] for localised error message.
class NoStoragePermissionException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.noStoragePermission;
}

class OtherDeviceBusyException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) {
    // TODO: implement getErrorMessage
    throw UnimplementedError();
  }
}
