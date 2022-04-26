import 'package:flutter/material.dart';
import 'dart:async' show StreamSubscription;

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
      Authgear(endpoint: "http://192.168.1.123:3100", clientID: "portal");

  StreamSubscription<SessionStateChangeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  Future<void> _configure() async {
    _sub = _authgear.onSessionStateChange.listen((e) {
      print("reason: ${e.reason}");
      print("sessionState: ${e.instance.sessionState}");
      setState(() {});
    });
    await _authgear.configure();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Plugin example app'),
            ),
            body: Center(
                child: Column(
              children: [
                TextButton(
                  onPressed: _authgear.sessionState == SessionState.noSession
                      ? _onPressAuthenticate
                      : null,
                  child: const Text("Authenticate"),
                ),
                TextButton(
                  onPressed:
                      _authgear.sessionState == SessionState.authenticated
                          ? () {
                              _onPressGetUserInfo(context);
                            }
                          : null,
                  child: const Text("Get UserInfo"),
                ),
                TextButton(
                  onPressed:
                      _authgear.sessionState == SessionState.authenticated
                          ? _onPressLogout
                          : null,
                  child: const Text("Logout"),
                ),
              ],
            )),
          );
        },
      ),
    );
  }

  Future<void> _onPressAuthenticate() async {
    try {
      final result = await _authgear.authenticate(redirectURI: redirectURI);
      print("result: ${result.userInfo.sub}");
    } catch (e) {
      print("error: $e");
    }
  }

  Future<void> _onPressLogout() async {
    await _authgear.logout();
  }

  Future<void> _onPressGetUserInfo(BuildContext context) async {
    final userInfo = await _authgear.getUserInfo();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("User Info"),
          content: Text(
            "sub: ${userInfo.sub}\nisAnonymous: ${userInfo.isAnonymous}\nisVerified: ${userInfo.isVerified}",
          ),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
