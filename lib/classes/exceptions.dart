import 'package:weepy/models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

abstract class FileDropException implements Exception {
  String getErrorMessage(AppLocalizations appLocalizations);
}

class FileCouldntSavedException implements FileDropException {
  final DbFile file;
  FileCouldntSavedException(this.file);

  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.unknownError;
}

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

class NoStoragePermissionException implements FileDropException {
  @override
  String getErrorMessage(AppLocalizations appLocalizations) =>
      appLocalizations.noStoragePermission;
}
