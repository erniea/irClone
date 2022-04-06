import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:irclone/chat_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyCybtkNwPRTD4Gs4sm4uV-4alupyuG5LOA",
          authDomain: "irclone.firebaseapp.com",
          projectId: "irclone",
          storageBucket: "irclone.appspot.com",
          messagingSenderId: "349437488054",
          appId: "1:349437488054:web:4e47dc40075d7d916fef17",
          measurementId: "G-PS2W9E5BHF"));
  runApp(const IrClone());
}

class IrClone extends StatelessWidget {
  const IrClone({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "title",
      home: AuthGate(key: key),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String str = "test";
  String? accessToken;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ChatMain(
            title: "channel name",
            channel: WebSocketChannel.connect(
              Uri.parse("wss://beta.ircta.lk/irctalk"),
            ),
            accessToken: accessToken == null ? "" : accessToken!,
          );
        } else {
          return Center(
            child: Column(
              children: [
                TextButton(
                    onPressed: () async {
                      var googleSignIn = GoogleSignIn(
                        clientId:
                            "349437488054-apko0h450gts1nqpfe9g085qrkgn2b1h.apps.googleusercontent.com",
                        scopes: [
                          'https://www.googleapis.com/auth/userinfo.email',
                          'https://www.googleapis.com/auth/userinfo.profile',
                        ],
                      );

                      var user = await googleSignIn.signIn();
                      var auth = await user?.authentication;
                      var cred = GoogleAuthProvider.credential(
                          accessToken: auth?.accessToken,
                          idToken: auth?.idToken);
                      await FirebaseAuth.instance.signInWithCredential(cred);

                      accessToken = auth?.accessToken;
                    },
                    child: const Text("sign in")),
              ],
            ),
          );
        }
      },
    );
  }
}

class ChatMain extends StatefulWidget {
  final String title;
  final WebSocketChannel channel;
  final String accessToken;

  const ChatMain(
      {Key? key,
      required this.title,
      required this.channel,
      required this.accessToken})
      : super(key: key);

  @override
  _ChatMainState createState() => _ChatMainState();
}

class _ChatMainState extends State<ChatMain> {
  final TextEditingController _controller = TextEditingController();
  String msgLog = "";
  int _msgId = 0;
  int _getMsgId() {
    return ++_msgId;
  }

  final List<Chat> _logs = [];

  @override
  void initState() {
    super.initState();
    widget.channel.stream.listen(_msgHandler);

    SharedPreferences.getInstance().then(
      (value) {
        String? authKey = value.getString("authKey");

        if (authKey == null || authKey.isEmpty) {
          var register = {
            "type": "register",
            "data": {"access_token": widget.accessToken},
            "msg_id": _getMsgId(),
          };
          _send(register);
        } else {
          _tryLogin(authKey);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: const Text("sign out"),
            ),
            Form(
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Send a message'),
              ),
            ),
            Expanded(
              child: ChatView(logs: _logs),
            ),
            Text(msgLog),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        child: const Icon(Icons.send),
      ),
    );
  }

  void _send(json) {
    log(json.toString());
    widget.channel.sink.add(jsonEncode(json));
  }

  void _tryLogin(authKey) {
    var login = {
      "type": "login",
      "data": {"auth_key": authKey},
      "msg_id": _getMsgId()
    };
    _send(login);
  }

  void _msgHandler(event) async {
    var json = jsonDecode(event.toString());
    switch (json["type"]) {
      case "register":
        var sp = await SharedPreferences.getInstance();
        sp.setString("authKey", json["data"]["auth_key"]);
        _tryLogin(json["data"]["auth_key"]);
        break;
      case "login":
        var reqServer = {
          "type": "getServers",
          "data": {},
          "msg_id": _getMsgId()
        };
        _send(reqServer);
        break;
      case "getServers":
        for (var channel in json["data"]["channels"]) {
          log(channel.toString());
        }
        break;
      case "pushLog":
      case "sendLog":
        var msg = json["data"]["log"];
        setState(() {
          _logs.add(Chat(
              channel: msg["channel"], from: msg["from"], msg: msg["message"]));
        });
        break;
    }

    setState(() {
      msgLog = event.toString();
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      widget.channel.sink.add(
          '{"type":"sendLog","data":{"server_id":2,"channel":"#erniea","message":"${_controller.text}"},"msg_id":${_getMsgId()}}');
      _controller.text = "";
    }
  }

  @override
  void dispose() {
    widget.channel.sink.close();
    super.dispose();
  }
}
