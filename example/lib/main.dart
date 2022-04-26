import 'dart:async' show StreamSubscription;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:flutter_authgear/authgear.dart';

void main() {
  // debugPaintSizeEnabled = true;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

const redirectURI = "com.authgear.exampleapp.flutter://host/path";

String _showError(dynamic e) {
  return "$e";
}

class TextFieldWithLabel extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;

  const TextFieldWithLabel({
    Key? key,
    required this.label,
    required this.hintText,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(label),
            ),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
              ),
            ),
          ],
        ));
  }
}

class SessionStateButton extends StatelessWidget {
  final SessionState sessionState;
  final SessionState targetState;
  final void Function()? onPressed;
  final String label;

  const SessionStateButton({
    Key? key,
    required this.sessionState,
    required this.targetState,
    required this.onPressed,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: sessionState == targetState ? onPressed : null,
      child: Text(label),
    );
  }
}

class _MyAppState extends State<MyApp> {
  Authgear _authgear = Authgear(endpoint: "", clientID: "");
  late SharedPreferences sharedPreferences;

  TextEditingController endpointController = TextEditingController();
  TextEditingController clientIDController = TextEditingController();

  StreamSubscription<SessionStateChangeEvent>? _sub;

  bool loading = false;

  bool get unconfigured {
    return _authgear.endpoint != endpointController.text ||
        _authgear.clientID != clientIDController.text;
  }

  @override
  void initState() {
    super.initState();
    endpointController.addListener(() {
      setState(() {});
    });
    clientIDController.addListener(() {
      setState(() {});
    });

    void init() async {
      sharedPreferences = await SharedPreferences.getInstance();
      final endpoint = sharedPreferences.getString("authgear.endpoint");
      final clientID = sharedPreferences.getString("authgear.clientID");
      if (endpoint != null && clientID != null) {
        endpointController.text = endpoint;
        clientIDController.text = clientID;
        await _onPressConfigure();
      }
    }

    init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    endpointController.dispose();
    clientIDController.dispose();
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
            body: ListView(
              children: [
                TextFieldWithLabel(
                  label: "Endpoint",
                  hintText: "Enter Authegar endpoint",
                  controller: endpointController,
                ),
                TextFieldWithLabel(
                  label: "Client ID",
                  hintText: "Enter client ID",
                  controller: clientIDController,
                ),
                TextButton(
                  onPressed: () {
                    _onPressConfigure();
                  },
                  child: const Text("Configure"),
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.noSession,
                  label: "Authenticate",
                  onPressed: unconfigured || loading
                      ? null
                      : () {
                          _onPressAuthenticate(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Get UserInfo",
                  onPressed: unconfigured || loading
                      ? null
                      : () {
                          _onPressGetUserInfo(context);
                        },
                ),
                SessionStateButton(
                  sessionState: _authgear.sessionState,
                  targetState: SessionState.authenticated,
                  label: "Logout",
                  onPressed: unconfigured || loading
                      ? null
                      : () {
                          _onPressLogout(context);
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _onPressAuthenticate(BuildContext context) async {
    try {
      setState(() {
        loading = true;
      });
      await _authgear.authenticate(redirectURI: redirectURI);
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _onPressGetUserInfo(BuildContext context) async {
    try {
      setState(() {
        loading = true;
      });
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
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _onPressLogout(BuildContext context) async {
    try {
      setState(() {
        loading = true;
      });
      await _authgear.logout();
    } catch (e) {
      onError(context, e);
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _onPressConfigure() async {
    final endpoint = endpointController.text;
    final clientID = clientIDController.text;

    final authgear = Authgear(endpoint: endpoint, clientID: clientID);
    _sub?.cancel();
    await authgear.configure();
    await sharedPreferences.setString(
      "authgear.endpoint",
      endpoint,
    );
    await sharedPreferences.setString(
      "authgear.clientID",
      clientID,
    );

    setState(() {
      _authgear = authgear;
      _sub = _authgear.onSessionStateChange.listen((e) {
        setState(() {});
      });
    });
  }

  void onError(BuildContext context, dynamic e) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(_showError(e)),
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
