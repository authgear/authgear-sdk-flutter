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

Future<void> openURL(String url) async {
  try {
    await _channel.invokeMethod("openURL", {
      "url": url,
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

Future<void> storageSetItem(String key, String value) async {
  try {
    await _channel.invokeMethod("storageSetItem", {
      "key": key,
      "value": value,
    });
  } on PlatformException catch (e) {
    throw _wrapException(e);
  }
}

Future<String?> storageGetItem(String key) async {
  try {
    return await _channel.invokeMethod("storageGetItem", {
      "key": key,
    });
  } on PlatformException catch (e) {
    throw _wrapException(e);
  }
}

Future<void> storageDeleteItem(String key) async {
  try {
    await _channel.invokeMethod("storageDeleteItem", {
      "key": key,
    });
  } on PlatformException catch (e) {
    throw _wrapException(e);
  }
}
