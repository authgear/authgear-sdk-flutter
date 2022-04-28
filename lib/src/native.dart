import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'exception.dart';
import 'type.dart';

const MethodChannel _channel = MethodChannel("flutter_authgear");

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
    throw wrapException(e);
  }
}

Future<void> openURL(String url) async {
  try {
    await _channel.invokeMethod("openURL", {
      "url": url,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<Map> getDeviceInfo() async {
  try {
    return await _channel.invokeMethod("getDeviceInfo");
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<void> storageSetItem(String key, String value) async {
  try {
    await _channel.invokeMethod("storageSetItem", {
      "key": key,
      "value": value,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String?> storageGetItem(String key) async {
  try {
    return await _channel.invokeMethod("storageGetItem", {
      "key": key,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<void> storageDeleteItem(String key) async {
  try {
    await _channel.invokeMethod("storageDeleteItem", {
      "key": key,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<void> checkBiometricSupported({
  required BiometricOptionsIOS ios,
  required BiometricOptionsAndroid android,
}) async {
  try {
    await _channel.invokeMethod("checkBiometricSupported", {
      "ios": ios.toMap(),
      "android": android.toMap(),
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}
