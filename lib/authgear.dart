import 'dart:async';
import 'package:flutter/services.dart';

class Authgear {
  static const MethodChannel _channel = MethodChannel('authgear');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
