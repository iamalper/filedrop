import 'package:weepy/models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

///Base class for FileDrop exceptions.
///
///Use [getErrorMessage] method for localised error messages.
abstract class FileDropException implements Exception {
  ///Returns localised simple error message for end user.
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

///Throws when an error happened during file send or receive.
///
///Use [getErrorMessage] for localised error message.
class ConnectionLostException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.connectionLost;
}

///Throws when storage permission request rejected by user.
///
///Use [getErrorMessage] for localised error message.
class NoStoragePermissionException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.noStoragePermission;
}

///Throws when user tired to send file but other device is busy.
///
///Use [getErrorMessage] for localised error message.
class OtherDeviceBusyException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.otherDeviceBusy;
}
