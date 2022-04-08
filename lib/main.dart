import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:html';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:irclone/view.dart';
import 'package:irclone/structure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyCybtkNwPRTD4Gs4sm4uV-4alupyuG5LOA",
            authDomain: "irclone.firebaseapp.com",
            projectId: "irclone",
            storageBucket: "irclone.appspot.com",
            messagingSenderId: "349437488054",
            appId: "1:349437488054:web:4e47dc40075d7d916fef17",
            measurementId: "G-PS2W9E5BHF"));
  } else {
    await Firebase.initializeApp();
  }
  runApp(const IrClone());
}

class IrClone extends StatelessWidget {
  const IrClone({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "irClone",
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
  String? accessToken;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ChatMain(
            channel: WebSocketChannel.connect(
              Uri.parse("wss://beta.ircta.lk:443/irctalk"),
            ),
            accessToken: accessToken ?? "",
          );
        } else {
          return Center(
            child: TextButton(
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
                      accessToken: auth?.accessToken, idToken: auth?.idToken);
                  await FirebaseAuth.instance.signInWithCredential(cred);

                  accessToken = auth?.accessToken;
                },
                child: const Text("google sign in")),
          );
        }
      },
    );
  }
}

class ChatMain extends StatefulWidget {
  final WebSocketChannel channel;
  final String accessToken;

  const ChatMain({Key? key, required this.channel, required this.accessToken})
      : super(key: key);

  @override
  _ChatMainState createState() => _ChatMainState();
}

class _ChatMainState extends State<ChatMain> {
  final TextEditingController _controller = TextEditingController();
  int _msgId = 0;
  int _getMsgId() {
    return ++_msgId;
  }

  String _currentChannel = "";
  int _currentServer = 0;

  final Map<int, Server> _servers = {};
  final List<ChannelForList> _channelsForList = [];
  final ScrollController _scrollController = ScrollController();

  bool _needsScroll = false;
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
    if (_needsScroll) {
      WidgetsBinding.instance?.addPostFrameCallback((_) => _scrollToEnd());
      _needsScroll = false;
    }
    return Scaffold(
      drawer: Drawer(
        child: _channelBuilder(context),
      ),
      appBar: AppBar(
        title: Text(_currentChannel),
        actions: [
          IconButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _currentChannel.isEmpty ||
                      _servers[_currentServer] == null ||
                      _servers[_currentServer]!.channels[_currentChannel] ==
                          null
                  ? Container()
                  : ChannelView(
                      controller: _scrollController,
                      channel:
                          _servers[_currentServer]!.channels[_currentChannel]!),
            ),
            TextField(
              autofocus: true,
              controller: _controller,
              onSubmitted: (text) {
                _sendMessage();
              },
              decoration: InputDecoration(
                  labelText: "Send a message",
                  suffixIcon: IconButton(
                      onPressed: _sendMessage, icon: const Icon(Icons.send))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelBuilder(context) {
    return ListView(
      children:
          _channelsForList.map((e) => _channelElement(context, e)).toList(),
    );
  }

  Widget _channelElement(context, key) {
    return ListTile(
      title: Text(key.channelName),
      onTap: () {
        setState(() {
          _currentServer = key.serverId;
          _currentChannel = key.channelName;
        });
        _needsScroll = true;

        Navigator.pop(context);
      },
    );
  }

  void _send(json) {
    log("<<< " + json.toString());
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
        for (var server in json["data"]["servers"]) {
          _servers[server["id"]] = Server(
              serverName: server["name"], myNick: server["user"]["nickname"]!);
        }
        for (var channel in json["data"]["channels"]) {
          _servers[channel["server_id"]]!.channels[channel["channel"]] =
              Channel();

          _channelsForList.add(ChannelForList(
              channelName: channel["channel"], serverId: channel["server_id"]));
        }

        // TODO: for debug
        setState(() {
          _currentServer = 2;
          _currentChannel = "#erniea";
        });

        var getInitLog = {
          "type": "getInitLogs",
          "data": {},
          "msg_id": _getMsgId()
        };
        _send(getInitLog);
        break;
      case "getInitLogs":
        setState(() {
          for (var msg in json["data"]["logs"]) {
            _addMsg(msg);
          }
        });
        _needsScroll = true;
        break;
      case "pushLog":
      case "sendLog":
        var msg = json["data"]["log"];
        setState(() {
          _addMsg(msg);
        });
        _needsScroll = true;
        break;
    }

    log(">>> " + json.toString());
  }

  void _addMsg(msg) {
    _servers[msg["server_id"]]!.channels[msg["channel"]]!.chats.add(
          Chat(
              timestamp: msg["timestamp"],
              from: msg["from"],
              msg: msg["message"],
              myMsg: msg["from"] == _servers[msg["server_id"]]!.myNick),
        );
  }

  void _scrollToEnd() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      var msg = {
        "type": "sendLog",
        "data": {
          "server_id": _currentServer,
          "channel": _currentChannel,
          "message": _controller.text
        },
        "msg_id": _getMsgId()
      };
      _send(msg);
      _controller.text = "";
    }
  }

  @override
  void dispose() {
    widget.channel.sink.close();
    super.dispose();
  }
}
