import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'exception.dart';

const MethodChannel _channel = MethodChannel("flutter_authgear");

Exception _wrapException(PlatformException e) {
  if (e.code == "CANCEL") {
    return CancelException();
  }
  return AuthgearException(e);
}

Future<String> authenticate(
    {required String url,
    required String redirectURI,
    required bool preferEphemeral}) async {
  try {
    return await _channel.invokeMethod("authenticate", {
      "url": url,
      "redirectURI": redirectURI,
      "preferEphemeral": preferEphemeral,
    });
  } on PlatformException catch (e) {
    throw _wrapException(e);
  }
}

Future<Map> getDeviceInfo() async {
  try {
    return await _channel.invokeMethod("getDeviceInfo");
  } on PlatformException catch (e) {
    throw _wrapException(e);
  }
}
