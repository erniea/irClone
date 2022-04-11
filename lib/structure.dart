import 'dart:collection';

class Chat {
  const Chat(
      {required this.logId,
      required this.timestamp,
      required this.from,
      required this.msg,
      required this.myMsg,
      required this.mentioned});

  final int logId;
  final int timestamp;
  final String? from;
  final String msg;
  final bool myMsg;
  final bool mentioned;
}

class Channel {
  List<Chat> chats = [];
}

class ChannelForList {
  ChannelForList({required this.channelName, required this.serverId});

  final String channelName;
  final int serverId;
  int newMsg = 0;
  bool toMe = false;
}

class Server {
  Server({required this.serverName, required this.myNick});
  final Map<String, Channel> channels = {};
  final String serverName;
  final String myNick;
}
