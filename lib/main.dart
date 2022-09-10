import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:irclone/irctalk.dart';
import 'package:irclone/view.dart';
import 'package:irclone/structure.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  runApp(const IrClone());
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
  final String accessToken;
  final GoogleSignIn googleSignIn;

  const ChatMain(
      {Key? key, required this.accessToken, required this.googleSignIn})
      : super(key: key);

  @override
  _ChatMainState createState() => _ChatMainState();
}

class _ChatMainState extends State<ChatMain> {
  final TextEditingController _controller = TextEditingController();

  String _currentChannel = "";
  int _currentServer = 0;

  final Map<int, Server> _servers = {};
  final List<ChannelForList> _channelsForList = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocus = FocusNode();
  bool _needsScroll = false;

  IrcTalk? _ircTalk;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      int? timeout = sp.getInt("timeout");
      if (timeout == null || timeout < DateTime.now().millisecondsSinceEpoch) {
        sp.setString("authKey", "");
      }

      _ircTalk = IrcTalk(storeAuth: _storeAuth, msgHandler: _msgHandler);
      _ircTalk?.createWebSocketChannel();
      _ircTalk?.initWebSocket(widget.accessToken, sp.getString("authKey"));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
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
                widget.googleSignIn.disconnect();
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
                      getPastLog: (lastLogId) {
                        _ircTalk?.sendGetPastLogs(
                            _currentServer, _currentChannel, lastLogId);
                      },
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

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      _ircTalk?.sendMessage(_currentServer, _currentChannel, _controller.text);
    }
    _controller.text = "";
  }

  void _storeAuth(authKey) async {
    var sp = await SharedPreferences.getInstance();
    sp.setString("authKey", authKey);
    sp.setInt("timeout", DateTime.now().millisecondsSinceEpoch + 604800000);
  }

  void _msgHandler(event) async {
    var json = jsonDecode(event.toString());

    switch (json["type"]) {
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
    bool myMsg = msg["from"] == _servers[msg["server_id"]]?.myNick;
    bool mentioned =
        !myMsg && msg["message"].contains(_servers[msg["server_id"]]?.myNick);
    _servers[msg["server_id"]]?.channels[msg["channel"]]?.chats.add(
          Chat(
              logId: msg["log_id"],
              timestamp: msg["timestamp"],
              from: msg["from"],
              msg: msg["message"],
              myMsg: myMsg,
              mentioned: mentioned),
        );

    if (isNewMsg) {
      if (msg["channel"] != _currentChannel ||
          msg["server_id"] != _currentServer) {
        for (var e in _channelsForList) {
          if (e.channelName == msg["channel"] &&
              e.serverId == msg["server_id"]) {
            ++e.newMsg;

            if (mentioned) {
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

  @override
  void dispose() {
    _scrollController.dispose();
    _chatFocus.dispose();
    _ircTalk?.close();
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
