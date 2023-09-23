import 'package:weepy/models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

///Base class for FileDrop exceptions.
///
///Use [getErrorMessage] method for localised error messages.
abstract class FileDropException implements Exception {
  ///Returns localised simple error message for end user.
  String getErrorMessage(AppLocalizations appLocalizations);
}

class FileCouldntSavedException implements FileDropException {
  final DbFile file;

  ///Throw when a downloaded file couldn't moved from temp folder to storage
  ///
  ///Use [getErrorMessage] for localised error message.
  ///
  ///Usually throws when device has no enough storage space.
  FileCouldntSavedException(this.file);

  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.fileCoulntSaved;
}

class IpException implements FileDropException {
  ///Throws when can't get its own ip adress.
  ///
  ///Use [getErrorMessage] for localised error message.
  ///
  ///Usually throws when don't connected to a network.

  IpException();
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.notConnectedToNetwork;
}

class ConnectionLostException implements FileDropException {
  ///Throws when an error happened during file send or receive.
  ///
  ///Use [getErrorMessage] for localised error message.
  ConnectionLostException();
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.connectionLost;
}

class NoStoragePermissionException implements FileDropException {
  ///Throws when storage permission request rejected by user.
  ///
  ///Use [getErrorMessage] for localised error message.
  NoStoragePermissionException();
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.noStoragePermission;
}

class OtherDeviceBusyException implements FileDropException {
  ///Throws when user tired to send file but other device is busy.
  ///
  ///Use [getErrorMessage] for localised error message.
  OtherDeviceBusyException();
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.otherDeviceBusy;
}
