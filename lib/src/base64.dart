import 'dart:convert' show base64Url;

String base64UrlEncode(List<int> bytes) {
  final padded = base64Url.encode(bytes);
  return padded.replaceAll(RegExp("="), "");
}

List<int> base64UrlDecode(String s) {
  final r = s.length % 4;
  final padding = r == 1
      ? "==="
      : r == 2
          ? "=="
          : r == 3
              ? "="
              : "";
  final padded = s + padding;
  return base64Url.decode(padded);
}
