import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'exception.dart';
import 'type.dart';

const MethodChannel _channel = MethodChannel("flutter_authgear");

Future<String> openAuthorizeURL({
  required String url,
  required String redirectURI,
  required bool preferEphemeral,
}) async {
  try {
    return await _channel.invokeMethod("openAuthorizeURL", {
      "url": url,
      "redirectURI": redirectURI,
      "preferEphemeral": preferEphemeral,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String> openAuthorizeURLWithWebView({
  required String methodChannelName,
  required String url,
  required String redirectURI,
  String? modalPresentationStyle,
  String? navigationBarBackgroundColor,
  String? navigationBarButtonTintColor,
  bool? iosIsInspectable,
  String? iosWechatRedirectURI,
  String? actionBarBackgroundColor,
  String? actionBarButtonTintColor,
  String? androidWechatRedirectURI,
}) async {
  try {
    return await _channel.invokeMethod("openAuthorizeURLWithWebView", {
      "methodChannelName": methodChannelName,
      "url": url,
      "redirectURI": redirectURI,
      "modalPresentationStyle": modalPresentationStyle,
      "navigationBarBackgroundColor": navigationBarBackgroundColor,
      "navigationBarButtonTintColor": navigationBarButtonTintColor,
      "iosIsInspectable": iosIsInspectable,
      "actionBarBackgroundColor": actionBarBackgroundColor,
      "actionBarButtonTintColor": actionBarButtonTintColor,
      "iosWechatRedirectURI": iosWechatRedirectURI,
      "androidWechatRedirectURI": androidWechatRedirectURI,
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
    await _channel.invokeMethod("storageSetItem", {"key": key, "value": value});
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String?> storageGetItem(String key) async {
  try {
    return await _channel.invokeMethod("storageGetItem", {"key": key});
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<void> storageDeleteItem(String key) async {
  try {
    await _channel.invokeMethod("storageDeleteItem", {"key": key});
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String> generateUUID() async {
  try {
    return await _channel.invokeMethod("generateUUID");
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

Future<String> createBiometricPrivateKey({
  required String kid,
  required Map<String, dynamic> payload,
  required BiometricOptionsIOS ios,
  required BiometricOptionsAndroid android,
}) async {
  try {
    return await _channel.invokeMethod("createBiometricPrivateKey", {
      "kid": kid,
      "payload": payload,
      "ios": ios.toMap(),
      "android": android.toMap(),
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<void> removeBiometricPrivateKey(String kid) async {
  try {
    return await _channel.invokeMethod("removeBiometricPrivateKey", {
      "kid": kid,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String> signWithBiometricPrivateKey({
  required String kid,
  required Map<String, dynamic> payload,
  required BiometricOptionsIOS ios,
  required BiometricOptionsAndroid android,
}) async {
  try {
    return await _channel.invokeMethod("signWithBiometricPrivateKey", {
      "kid": kid,
      "payload": payload,
      "ios": ios.toMap(),
      "android": android.toMap(),
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String> createAnonymousPrivateKey({
  required String kid,
  required Map<String, dynamic> payload,
}) async {
  try {
    return await _channel.invokeMethod("createAnonymousPrivateKey", {
      "kid": kid,
      "payload": payload,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<void> removeAnonymousPrivateKey(String kid) async {
  try {
    return await _channel.invokeMethod("removeAnonymousPrivateKey", {
      "kid": kid,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String> signWithAnonymousPrivateKey({
  required String kid,
  required Map<String, dynamic> payload,
}) async {
  try {
    return await _channel.invokeMethod("signWithAnonymousPrivateKey", {
      "kid": kid,
      "payload": payload,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<bool> checkDPoPSupported() async {
  try {
    return await _channel.invokeMethod("checkDPoPSupported", {});
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<void> createDPoPPrivateKey({required String kid}) async {
  try {
    return await _channel.invokeMethod("createDPoPPrivateKey", {"kid": kid});
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String> signWithDPoPPrivateKey({
  required String kid,
  required Map<String, dynamic> payload,
}) async {
  try {
    return await _channel.invokeMethod("signWithDPoPPrivateKey", {
      "kid": kid,
      "payload": payload,
    });
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<bool> checkDPoPPrivateKey({required String kid}) async {
  try {
    return await _channel.invokeMethod("checkDPoPPrivateKey", {"kid": kid});
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}

Future<String> computeDPoPJKT({required String kid}) async {
  try {
    return await _channel.invokeMethod("computeDPoPJKT", {"kid": kid});
  } on PlatformException catch (e) {
    throw wrapException(e);
  }
}
