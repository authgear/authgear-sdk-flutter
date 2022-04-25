import 'dart:math' show Random;
import 'dart:convert' show utf8, base64Url;
import 'package:crypto/crypto.dart' show sha256;
import 'package:hex/hex.dart' show HEX;

String _base64UrlEncode(List<int> bytes) {
  final padded = base64Url.encode(bytes);
  return padded.replaceAll(RegExp("="), "");
}

String _computeCodeChallenge(String codeVerifier) {
  final data = utf8.encode(codeVerifier);
  final digest = sha256.convert(data);
  return _base64UrlEncode(digest.bytes);
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
