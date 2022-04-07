import 'dart:collection';

class Chat {
  const Chat({required this.timestamp, required this.from, required this.msg});

  final int timestamp;
  final String from;
  final String msg;
}

class Channel {
  List<Chat> chats = [];
}

class Server {
  late Map<String, Channel> channels = {};
}
