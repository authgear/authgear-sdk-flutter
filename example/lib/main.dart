import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_authgear/authgear.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

const redirectURI = "com.authgear.exampleapp.flutter://host/path";

class _MyAppState extends State<MyApp> {
  final Authgear _authgear =
      Authgear(endpoint: "http://192.168.1.235:3100", clientID: "portal");

  @override
  void initState() {
    super.initState();
    _configure();
  }

  Future<void> _configure() async {
    await _authgear.configure();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: TextButton(
            onPressed: _onPress,
            child: const Text("Authenticate"),
          ),
        ),
      ),
    );
  }

  Future<void> _onPress() async {
    try {
      final result = _authgear.authenticate(redirectURI: redirectURI);
      print("result: $result");
    } catch (e) {
      print("error: $e");
    }
  }
}
