import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:irclone/structure.dart';

class ChannelView extends StatefulWidget {
  const ChannelView({Key? key, required this.channel}) : super(key: key);
  final Channel channel;
  @override
  State<ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends State<ChannelView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: widget.channel.chats.map((e) => ChatView(chat: e)).toList(),
    );
  }
}

class ChatView extends StatelessWidget {
  const ChatView({Key? key, required this.chat}) : super(key: key);
  final Chat chat;
  @override
  Widget build(BuildContext context) {
    var time = DateTime.fromMillisecondsSinceEpoch(chat.timestamp);
    return ListTile(
      title: Text("${time.hour}:${time.minute} <${chat.from}> ${chat.msg}"),
    );
  }
}
