import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:irclone/structure.dart';
import 'package:bubble/bubble.dart';

class ChannelView extends StatefulWidget {
  const ChannelView({Key? key, required this.channel, required this.controller})
      : super(key: key);
  final Channel channel;
  final ScrollController controller;
  @override
  State<ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends State<ChannelView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.controller,
      children: _createChatView(widget.channel.chats),
    );
  }

  List<Widget> _createChatView(List<Chat> chats) {
    List<Widget> result = [];

    String prevFrom = "";
    for (Chat c in chats) {
      bool sameFrom = (c.from == prevFrom);
      if (!sameFrom) {
        prevFrom = c.from;
      }
      result.add(ChatView(chat: c, sameFrom: sameFrom));
    }

    return result;
  }
}

class ChatView extends StatelessWidget {
  const ChatView({Key? key, required this.chat, required this.sameFrom})
      : super(key: key);
  final Chat chat;
  final bool sameFrom;
  @override
  Widget build(BuildContext context) {
    var time = DateTime.fromMillisecondsSinceEpoch(chat.timestamp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chat.myMsg
            ? Container()
            : (sameFrom
                ? Container(
                    margin: EdgeInsets.only(left: 30),
                  )
                : Text(chat.from)),
        Row(
          children: [
            chat.myMsg ? Text("${time.hour}:${time.minute}") : Container(),
            Bubble(
              margin: BubbleEdges.only(bottom: 10, left: sameFrom ? 8 : 0),
              alignment: chat.myMsg ? Alignment.topRight : Alignment.topLeft,
              nip: sameFrom
                  ? BubbleNip.no
                  : (chat.myMsg ? BubbleNip.rightTop : BubbleNip.leftTop),
              color: chat.myMsg
                  ? const Color.fromRGBO(225, 255, 199, 1.0)
                  : Colors.white,
              child: SelectableText(chat.msg),
            ),
          ],
        ),
      ],
    );

    return Row(
      children: [
        Text("<${chat.from}>"),
        Expanded(child: Text(chat.msg)),
        Text("${time.hour}:${time.minute}")
      ],
    );
  }
}
