import 'package:weepy/classes/exceptions.dart';

///Sends when a progress updated.
///
///Read new percent from [newPercent]
class UpdatePercent {
  ///The new percent of progress.
  ///
  ///It maybe same previous sent [newPercent] and it must between `0.00` and `1.00`
  final double newPercent;
  const UpdatePercent(this.newPercent);
}

///Sends when an error caused from worker.
///
///Read error details from [exception.getErrorMessage(appLocalizations)]
class FiledropError {
  final FileDropException exception;
  const FiledropError(this.exception);
}
