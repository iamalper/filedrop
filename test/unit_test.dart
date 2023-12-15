import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nesne test', () {
    final sayi = Random().nextInt(1000);
    expect(_ParentNesne(sayi).getSayi(), sayi);
  });
}

class _ChildNesne {
  final int code;
  _ChildNesne([int? code]) : code = code ?? Random().nextInt(1000);
}

class _ParentNesne extends _ChildNesne {
  int getSayi() {
    return super.code;
  }

  _ParentNesne([super.randomSayi]);
}
