import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/exception.dart';

void main() {
  test("decodeException", () {
    expect("${decodeException(null)}", "${Exception('null')}");
    expect("${decodeException(Exception("a"))}", "${Exception('a')}");

    final result = decodeException({
      "name": "name",
      "reason": "reason",
      "message": "message",
    });
    final expected = ServerException(
        name: "name", reason: "reason", message: "message", info: null);

    expect(result, isA<ServerException>());

    final actual = result as ServerException;
    expect(actual.name, expected.name);
    expect(actual.reason, expected.reason);
    expect(actual.message, expected.message);
  });
}
