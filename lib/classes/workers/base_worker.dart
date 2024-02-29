import 'dart:isolate';

///Base class for implementing workers communication.
///
///Worker classes meant to manage workers.
///It run in main isolate, but workers run separated isolates.
abstract class BaseWorker {
  ///Whether if worker is active.
  Future<bool> isActive();

  ///Stop worker and clean all resources.
  Future<void> stop();

  ///Creates [ReceivePort] for worker to main isolate communication and registers.
  ///
  ///Calling more than one, throws.
  ReceivePort getReceivePort();

  ///Looks up for the [SendPort] registered for main isolate to worker communication.
  ///
  ///Call it every time you need the [SendPort], instead storing as variable.
  SendPort? getSendPort();
}
