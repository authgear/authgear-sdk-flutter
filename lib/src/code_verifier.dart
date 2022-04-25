import 'dart:math' show Random;
import 'dart:convert' show utf8;
import 'package:crypto/crypto.dart' show sha256;
import 'package:hex/hex.dart' show HEX;
import 'base64.dart';

String _computeCodeChallenge(String codeVerifier) {
  final data = utf8.encode(codeVerifier);
  final digest = sha256.convert(data);
  return base64UrlEncode(digest.bytes);
}

class CodeVerifier {
  late String _value;
  String get value => _value;

  late String _codeChallenge;
  String get codeChallenge => _codeChallenge;

  CodeVerifier(Random rng) {
    final bytes = List<int>.generate(32, (_i) => rng.nextInt(256));
    _value = HEX.encode(bytes);

    _codeChallenge = _computeCodeChallenge(_value);
  }
}
