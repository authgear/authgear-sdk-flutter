import 'dart:convert' show base64Url;

String base64UrlEncode(List<int> bytes) {
  final padded = base64Url.encode(bytes);
  return padded.replaceAll(RegExp("="), "");
}
