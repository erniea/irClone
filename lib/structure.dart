import 'dart:collection';

class Chat {
  const Chat({required this.from, required this.msg});
  final String from;
  final String msg;
}

class Channel {
  List<Chat> chats = [];
}

class Server {
  late Map<String, Channel> channels = {};
}
