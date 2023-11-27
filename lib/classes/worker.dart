import 'dart:developer';
import 'dart:ui';
import 'package:workmanager/workmanager.dart';

enum MyTasks { receive }

enum IsolatePorts { receive }

final _workManager = Workmanager();

@pragma("vm:entry-point")
void _callBack() {
  _workManager.executeTask((taskName, inputData) async {
    final task =
        MyTasks.values.singleWhere((element) => element.name == taskName);
    switch (task) {
      case MyTasks.receive:
        final sendPort =
            IsolateNameServer.lookupPortByName(IsolatePorts.receive.name);
        return true;
    }
  });
}

Future<void> initalize() async {
  throw UnimplementedError();
  // ignore: dead_code
  await _workManager.initialize(_callBack);
}
