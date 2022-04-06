import 'package:flutter/material.dart';

class Chat {
  const Chat({required this.channel, required this.from, required this.msg});
  final String channel;
  final String from;
  final String msg;
}

class ChatView extends StatefulWidget {
  const ChatView({Key? key, required this.logs}) : super(key: key);
  final List<Chat> logs;
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  @override
  Widget build(BuildContext context) {
    List<ListTile> chats = [];
    for (Chat c in widget.logs) {
      chats.add(
        ListTile(
          title: Text("${c.channel} <${c.from}> ${c.msg}"),
        ),
      );
    }

    return ListView(
      children: chats,
    );
  }
}
