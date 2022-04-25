import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_authgear/src/container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Authgear constructor', () async {
    var _ = Authgear(clientID: "clientID", endpoint: "http://localhost:3000");
  });

  test('StreamController.broadcast can have multiple subscribers', () async {
    final controller = StreamController<int>.broadcast(sync: true);
    final stream = controller.stream;

    int total = 0;

    stream.listen((data) {
      total += data;
    });
    stream.listen((data) {
      total += data;
    });

    controller.add(1);
    controller.add(2);

    expect(total, 6);
  });
}
