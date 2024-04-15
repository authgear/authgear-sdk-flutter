import 'dart:math' show Random;
import 'dart:convert' show utf8;
import 'package:crypto/crypto.dart' show sha256;
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
    // https://datatracker.ietf.org/doc/html/rfc7636#section-4.1
    // It is RECOMMENDED that the output of
    // a suitable random number generator be used to create a 32-octet
    // sequence.  The octet sequence is then base64url-encoded to produce a
    // 43-octet URL safe string to use as the code verifier.
    final bytes = List<int>.generate(32, (_i) => rng.nextInt(256));
    _value = base64UrlEncode(bytes);
    _codeChallenge = _computeCodeChallenge(_value);
  }
}
