import 'dart:math' show Random;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/code_verifier.dart';

void main() {
  test('CodeVerifier', () {
    final rng = Random(0);
    final codeVerifier = CodeVerifier(rng);
    expect(codeVerifier.value.runes.length, 43);
    expect(codeVerifier.value, "jwEcs37HXgmZafciKLgzfsHtgJ3b714dhEop8Lzq_n4");
    expect(codeVerifier.codeChallenge,
        "JO1aklO5DCWCdDvEvCWJIKSuZmfQ25kyrNIEeSiahz4");
  });
}
