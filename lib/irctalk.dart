import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class IrcTalk {
  final Uri ircTalk = Uri.parse("wss://beta.ircta.lk/irctalk");
  final Map<String, dynamic> headers = {"Origin": "https://beta.ircta.lk"};

  final Function msgHandler;
  final Function storeAuth;
  int keepAlive = 1800;

  WebSocketChannel? webSocketChannel;

  IrcTalk({required this.msgHandler, required this.storeAuth});

  int _msgId = 0;
  int _getMsgId() => ++_msgId;

  void createWebSocketChannel() {
    webSocketChannel = kIsWeb
        ? WebSocketChannel.connect(ircTalk)
        : IOWebSocketChannel.connect(
            ircTalk,
            headers: headers,
          );
  }

  void initWebSocket(accessToken, authKey) {
    webSocketChannel?.stream.listen(_msgHandler);
    if (authKey == null || authKey.isEmpty) {
      _register(accessToken);
    } else {
      _tryLogin(authKey);
    }
  }

  void close() {
    webSocketChannel?.sink.close();
  }

  void _register(accessToken) {
    var register = {
      "type": "register",
      "data": {"access_token": accessToken},
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

  void _send(json) {
    log("<<< " + json.toString());
    webSocketChannel?.sink.add(jsonEncode(json));
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

  void sendGetPastLogs(currentServer, currentChannel, lasglogid) {
    var getPastLogs = {
      "type": "getPastLogs",
      "data": {
        "server_id": currentServer,
        "channel": currentChannel,
        "last_log_id": lasglogid
      },
      "msg_id": _getMsgId()
    };
    _send(getPastLogs);
  }

  void _getInitLog() {
    var getInitLog = {"type": "getInitLogs", "data": {}, "msg_id": _getMsgId()};
    _send(getInitLog);
  }

  void sendMessage(currentServer, currentChannel, text) {
    var msg = {
      "type": "sendLog",
      "data": {
        "server_id": currentServer,
        "channel": currentChannel,
        "message": text
      },
      "msg_id": _getMsgId()
    };
    _send(msg);
  }

  Future<void> _msgHandler(event) async {
    var json = jsonDecode(event.toString());
    log(">>> " + json.toString());

    msgHandler(event);
    switch (json["type"]) {
      case "ping":
        _reservePing();
        break;
      case "register":
        storeAuth(json["data"]["auth_key"]);
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
        _getInitLog();
        break;
    }
  }
}