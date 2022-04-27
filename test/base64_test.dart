import 'dart:convert' show utf8;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/base64.dart';

void main() {
  test("base64", () {
    void symmetric(String data) {
      final bytes = utf8.encode(data);
      final encoded = base64UrlEncode(bytes);
      final decoded = base64UrlDecode(encoded);
      final actual = utf8.decode(decoded);
      expect(data, actual);
    }

    symmetric("");
    symmetric("a");
    symmetric("ab");
    symmetric("abc");
    symmetric("abcd");
    symmetric("abcde");
    symmetric("abcdef");
    symmetric("abcdefg");
    symmetric("abcdefgh");
    symmetric("abcdefghi");
  });
}
