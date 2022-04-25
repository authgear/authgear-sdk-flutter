import 'package:flutter/services.dart' show MethodChannel;

const MethodChannel _channel = MethodChannel("flutter_authgear");

Future<String> authenticate(
    {required String url,
    required String redirectURI,
    required bool preferEphemeral}) async {
  return await _channel.invokeMethod("authenticate", {
    "url": url,
    "redirectURI": redirectURI,
    "preferEphemeral": preferEphemeral,
  });
}

Future<Map> getDeviceInfo() async {
  return await _channel.invokeMethod("getDeviceInfo");
}
