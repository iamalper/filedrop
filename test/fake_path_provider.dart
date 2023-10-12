import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    Directory(p.absolute("tmp")).createSync();
    return p.absolute("tmp");
  }

  @override
  Future<String?> getDownloadsPath() async {
    Directory(p.absolute("tmp")).createSync();
    return p.absolute("tmp");
  }
}
