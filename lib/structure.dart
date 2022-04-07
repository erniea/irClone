import 'dart:collection';

class Chat {
  const Chat(
      {required this.timestamp,
      required this.from,
      required this.msg,
      required this.myMsg});

  final int timestamp;
  final String from;
  final String msg;
  final bool myMsg;
}

class Channel {
  List<Chat> chats = [];
}

class Server {
  Server({required this.myNick});
  final Map<String, Channel> channels = {};
  final String myNick;
}
