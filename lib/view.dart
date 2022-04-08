import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    DateTime prevTime = DateTime.fromMicrosecondsSinceEpoch(0);
    for (Chat c in chats) {
      bool sameFrom = (c.from == prevFrom);
      if (!sameFrom) {
        prevFrom = c.from ?? "";
      }

      var time = DateTime.fromMillisecondsSinceEpoch(c.timestamp);
      bool sameDay = (time.day == prevTime.day);

      bool sameTime = sameFrom &&
          (time.hour == prevTime.hour && time.minute == prevTime.minute);

      if (!sameDay) {
        result.add(Bubble(
          margin: const BubbleEdges.only(top: 10),
          padding: const BubbleEdges.all(3),
          alignment: Alignment.center,
          color: const Color.fromRGBO(212, 234, 244, 1.0),
          child: Text(DateFormat.yMd().format(time)),
        ));
      }
      if (!sameTime) {
        prevTime = time;
      }

      result.add(ChatView(
        chat: c,
        sameFrom: sameFrom,
        sameTime: sameTime,
      ));
    }

    return result;
  }
}

class ChatView extends StatelessWidget {
  const ChatView(
      {Key? key,
      required this.chat,
      required this.sameFrom,
      required this.sameTime})
      : super(key: key);
  final Chat chat;
  final bool sameFrom;
  final bool sameTime;
  @override
  Widget build(BuildContext context) {
    var time = DateTime.fromMillisecondsSinceEpoch(chat.timestamp);
    return chat.from == null
        ? _createEmptyBubbleMsg(time)
        : chat.myMsg
            ? _createMyBubbleMsg(time, sameFrom, sameTime)
            : _createOtherBubbleMsg(time, sameFrom, sameTime);
  }

  Widget _createEmptyBubbleMsg(time) {
    return Bubble(
      stick: true,
      margin: const BubbleEdges.only(top: 10),
      padding: const BubbleEdges.all(3),
      color: const Color.fromRGBO(212, 234, 244, 1.0),
      child: Text(chat.msg, textAlign: TextAlign.center),
    );
  }

  Widget _createMyBubbleMsg(time, sameFrom, sameTime) {
    List<Widget> inColumnChildren = [];

    if (!sameTime) {
      inColumnChildren.add(Text(
        DateFormat.Hm().format(time),
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 10),
      ));
    }
    inColumnChildren.add(SelectableText(
      chat.msg,
      style: const TextStyle(height: 1),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Bubble(
          margin: BubbleEdges.only(bottom: 4, right: sameTime ? 8 : 0),
          padding: const BubbleEdges.all(10),
          alignment: Alignment.topRight,
          // nip: sameFrom && sameTime ? BubbleNip.no : BubbleNip.rightTop,
          color: const Color.fromRGBO(225, 255, 199, 1.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: inColumnChildren),
        ),
      ],
    );
  }

  Widget _createOtherBubbleMsg(time, sameFrom, sameTime) {
    List<Widget> inColumnChildren = [];
    if (!sameTime) {
      inColumnChildren.add(Text(
        DateFormat.Hm().format(time),
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 10),
      ));
    }

    inColumnChildren.add(SelectableText(
      chat.msg,
      style: const TextStyle(height: 1),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sameFrom ? Container() : Text(chat.from!),
        Bubble(
          margin: BubbleEdges.only(bottom: 4, left: sameTime ? 8 : 0),
          padding: const BubbleEdges.all(10),
          alignment: Alignment.topLeft,
          //nip: sameFrom && sameTime ? BubbleNip.no : BubbleNip.leftTop,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: inColumnChildren,
          ),
        ),
      ],
    );
  }
}
