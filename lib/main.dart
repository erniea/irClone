import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:irclone/view.dart';
import 'package:irclone/structure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'package:google_sign_in/google_sign_in.dart';

final Uri ircTalk = Uri.parse("wss://beta.ircta.lk/irctalk");
final Map<String, dynamic> headers = {"Origin": "https://beta.ircta.lk"};

Future<void> main() async {
  runApp(const IrClone());
}

WebSocketChannel createWebSocketChannel() {
  return kIsWeb
      ? WebSocketChannel.connect(ircTalk)
      : IOWebSocketChannel.connect(
          ircTalk,
          headers: headers,
        );
}

class IrClone extends StatelessWidget {
  const IrClone({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "irClone",
      home: AuthGate(key: key),
      theme: ThemeData(primarySwatch: Colors.grey),
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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        "349437488054-apko0h450gts1nqpfe9g085qrkgn2b1h.apps.googleusercontent.com",
    scopes: [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  @override
  void initState() {
    super.initState();
    _googleSignIn.signInSilently();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _googleSignIn.onCurrentUserChanged,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          var account = snapshot.data as GoogleSignInAccount;

          if (accessToken == null) {
            account.authentication.then((value) {
              setState(() {
                accessToken = value.accessToken;
              });
            });
          }

          return accessToken == null
              ? Container()
              : ChatMain(
                  webSocketChannel: createWebSocketChannel(),
                  accessToken: accessToken ?? "",
                  googleSignIn: _googleSignIn,
                );
        } else {
          return Center(
            child: TextButton(
                onPressed: () {
                  _googleSignIn.signIn();
                },
                child: const Text("google sign in")),
          );
        }
      },
    );
  }
}

class ChatMain extends StatefulWidget {
  WebSocketChannel webSocketChannel;
  final String accessToken;
  final GoogleSignIn googleSignIn;

  ChatMain(
      {Key? key,
      required this.webSocketChannel,
      required this.accessToken,
      required this.googleSignIn})
      : super(key: key);

  @override
  _ChatMainState createState() => _ChatMainState();
}

class _ChatMainState extends State<ChatMain> {
  final TextEditingController _controller = TextEditingController();
  int _msgId = 0;
  int _getMsgId() => ++_msgId;

  String _currentChannel = "";
  int _currentServer = 0;

  final Map<int, Server> _servers = {};
  final List<ChannelForList> _channelsForList = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocus = FocusNode();
  bool _needsScroll = false;
  int keepAlive = 0;

  late StreamSubscription<FGBGType> _fgbg;
  Timer? checkPing = null;
  void _fgbgHandler(event) {
    dev.log(event.toString());

    if (event == FGBGType.foreground) {
      checkPing = Timer(const Duration(milliseconds: 300), () {
        widget.webSocketChannel = createWebSocketChannel();

        SharedPreferences.getInstance().then((sp) {
          _initWebSocket(sp.getString("authKey"));
        });
      });
      _sendPing();
    }
  }

  void _initWebSocket(authKey) {
    widget.webSocketChannel.stream.listen(_msgHandler);
    if (authKey == null || authKey.isEmpty) {
      _register();
    } else {
      _tryLogin(authKey);
    }
  }

  @override
  void initState() {
    super.initState();
    _fgbg = FGBGEvents.stream.listen(_fgbgHandler);
    SharedPreferences.getInstance().then((sp) {
      _initWebSocket(sp.getString("authKey"));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsScroll) {
      WidgetsBinding.instance?.addPostFrameCallback((_) => _scrollToEnd());
      _needsScroll = false;
    }

    return Scaffold(
      drawer: ChannelDrawer(
        servers: _servers,
        channels: _channelsForList,
        onChannelSelected: (server, channel) {
          setState(() {
            _currentServer = server;
            _currentChannel = channel;
            _needsScroll = true;
          });
          SharedPreferences.getInstance().then((sp) {
            sp.setInt("server", _currentServer);
            sp.setString("channel", _currentChannel);
          });
        },
        sendAddChannelToServer: (server, channel) =>
            _sendAddChannelToServer(server, channel),
        sendAddServer: (serverName, serverAddress, serverPort, useSSL, nickName,
                realName) =>
            _sendAddServer(serverName, serverAddress, serverPort, useSSL,
                nickName, realName),
        currentServer: _currentServer,
        currentChannel: _currentChannel,
      ),
      appBar: AppBar(
        title: Text(_currentChannel),
        actions: [
          IconButton(
              onPressed: () {
                widget.googleSignIn.signOut();
                if (kIsWeb) {
                  widget.googleSignIn.disconnect();
                }
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
                      getPastLog: _sendGetPastLog,
                      controller: _scrollController,
                      channel:
                          _servers[_currentServer]!.channels[_currentChannel]!),
            ),
            TextField(
              controller: _controller,
              focusNode: _chatFocus,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                _sendMessage();
                _chatFocus.requestFocus();
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

  void _send(json) {
    dev.log("<<< " + json.toString());
    widget.webSocketChannel.sink.add(jsonEncode(json));
  }

  void _register() {
    var register = {
      "type": "register",
      "data": {"access_token": widget.accessToken},
      "msg_id": _getMsgId(),
    };
    _send(register);
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

    dev.log(">>> " + json.toString());
    switch (json["type"]) {
      case "ping":
        if (checkPing != null) {
          checkPing!.cancel();
          checkPing = null;
        } else {
          _reservePing();
        }
        break;
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
        keepAlive = json["data"]["keepalive"];
        _reservePing();
        break;
      case "getServers":
        for (var server in json["data"]["servers"]) {
          _addServer(server);
        }

        _channelsForList.clear();
        for (var channel in json["data"]["channels"]) {
          _addChannel(channel);
        }

        _channelsForList.sort(
          (a, b) => a.channelName.compareTo(b.channelName),
        );

        {
          var sp = await SharedPreferences.getInstance();
          String? channel = sp.getString("channel");

          if (channel != null && channel.isNotEmpty) {
            setState(() {
              _currentServer = sp.getInt("server")!;
              _currentChannel = channel;
            });
          }
        }

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
            _addMsg(msg, false);
          }
        });
        _needsScroll = true;
        break;
      case "pushLog":
      case "sendLog":
        var msg = json["data"]["log"];
        setState(() {
          _addMsg(msg, true);
        });
        if (_scrollController.position.pixels ==
            _scrollController.position.minScrollExtent) {
          _needsScroll = true;
        }
        break;
      case "getPastLogs":
        setState(() {
          for (var msg in json["data"]["logs"]) {
            _addMsg(msg, false);
          }
          _servers[_currentServer]!.channels[_currentChannel]!.chats.sort(
                (a, b) => a.logId - b.logId,
              );
        });

        break;
    }
  }

  void _addServer(server) {
    _servers[server["id"]] =
        Server(serverName: server["name"], myNick: server["user"]["nickname"]!);
  }

  void _sendAddChannelToServer(server, channel) {
    if (channel.isNotEmpty) {
      if (channel[0] != "#") {
        channel = "#" + channel;
      }
      if (channel.length > 1) {
        _notImpl();
      }
    }
  }

  void _sendAddServer(
      serverName, serverAddress, serverPort, useSSL, nickName, realName) {
    _notImpl();
  }

  void _addChannel(channel) {
    _servers[channel["server_id"]]!.channels[channel["channel"]] = Channel();

    _channelsForList.add(ChannelForList(
        channelName: channel["channel"], serverId: channel["server_id"]));
  }

  void _addMsg(msg, isNewMsg) {
    _servers[msg["server_id"]]?.channels[msg["channel"]]?.chats.add(
          Chat(
              logId: msg["log_id"],
              timestamp: msg["timestamp"],
              from: msg["from"],
              msg: msg["message"],
              myMsg: msg["from"] == _servers[msg["server_id"]]?.myNick,
              mentioned:
                  msg["message"].contains(_servers[msg["server_id"]]?.myNick)),
        );

    if (isNewMsg) {
      if (msg["channel"] != _currentChannel ||
          msg["server_id"] != _currentServer) {
        for (var e in _channelsForList) {
          if (e.channelName == msg["channel"] &&
              e.serverId == msg["server_id"]) {
            ++e.newMsg;

            if (msg["message"].contains(_servers[msg["server_id"]]?.myNick)) {
              e.toMe = true;
            }
          }
        }
      }
    }
  }

  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
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
    }
    _controller.clear();
  }

  void _reservePing() {
    if (keepAlive > 0) {
      Timer(Duration(seconds: (keepAlive - 800)), _sendPing);
    }
  }

  void _sendPing() {
    var ping = {"type": "ping", "data": {}, "msg_id": _getMsgId()};

    _send(ping);
  }

  void _sendGetPastLog(lasglogid) {
    var getPastLogs = {
      "type": "getPastLogs",
      "data": {
        "server_id": _currentServer,
        "channel": _currentChannel,
        "last_log_id": lasglogid
      },
      "msg_id": _getMsgId()
    };
    _send(getPastLogs);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _chatFocus.dispose();
    _fgbg.cancel();
    widget.webSocketChannel.sink.close();
    dev.log("dispose");
    super.dispose();
  }

  void _notImpl() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Not implemented yet"),
            content: const Text("아직 구현되지 않은 기능입니다"),
            actions: [
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"))
            ],
          );
        });
  }
}
