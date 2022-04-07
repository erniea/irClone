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
    return ListView.builder(
        itemCount: widget.channel.chats.length,
        itemBuilder: ((context, index) {
          return ListTile(
            title: Text(
                "<${widget.channel.chats[index].from}> ${widget.channel.chats[index].msg}"),
          );
        }));
  }
}
