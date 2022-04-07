import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:irclone/structure.dart';

class ChatView extends StatefulWidget {
  const ChatView({Key? key, required this.channel}) : super(key: key);
  final Channel channel;
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: widget.channel.chats.map((e) => _chat(e)).toList(),
    );
  }

  Widget _chat(Chat c) {
    return ListTile(
      title: Text("<${c.from}> ${c.msg}"),
    );
  }
}
