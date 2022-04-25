import 'dart:math' show Random;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/code_verifier.dart';

void main() {
  test('CodeVerifier', () {
    final rng = Random(0);
    final codeVerifier = CodeVerifier(rng);
    expect(codeVerifier.value,
        "8f011cb37ec75e099969f72228b8337ec1ed809ddbef5e1d844a29f0bceafe7e");
    expect(codeVerifier.codeChallenge,
        "wwOl-gkE1Q8-wqEVWep4uYe2wYR7k73M9JMXUjtSx80");
  });
}
