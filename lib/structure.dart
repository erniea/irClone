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
  Channel({required this.members, required this.channelTopic});

  List<Chat> chats = [];
  List<String> members = [];
  final String channelTopic;
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
