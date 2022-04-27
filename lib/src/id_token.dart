import 'dart:convert' show utf8, jsonDecode;
import 'base64.dart';

Map<String, dynamic> decodeIDToken(String idToken) {
  final parts = idToken.split(".");
  if (parts.length != 3) {
    throw Exception("invalid ID token: $idToken");
  }
  final payload = parts[1];
  final utf8bytes = base64UrlDecode(payload);
  final utf8Str = utf8.decode(utf8bytes);
  return jsonDecode(utf8Str);
}
