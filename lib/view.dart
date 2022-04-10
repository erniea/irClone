import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:irclone/structure.dart';
import 'package:bubble/bubble.dart';
import 'package:url_launcher/url_launcher.dart';

class ChannelView extends StatefulWidget {
  const ChannelView({Key? key, required this.channel, required this.controller})
      : super(key: key);
  final Channel channel;
  final ScrollController controller;
  @override
  State<ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends State<ChannelView> {
  List<Widget> chatViewItems = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    chatViewItems = _createChatView(widget.channel.chats);

    return ListView.builder(
      controller: widget.controller,
      //children: _createChatView(widget.channel.chats),
      itemBuilder: (c, i) => chatViewItems[chatViewItems.length - i - 1],
      itemCount: chatViewItems.length,
      reverse: true,
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

  static const nickColors = [
    Color(0xff0000bb),
    Color(0xff00bb00),
    Color(0xffff5555),
    Color(0xffbb0000),
    Color(0xffbb00bb),
    Color(0xffbbbb00),
    Color(0xff55ff55),
    Color(0xff00bbbb),
    Color(0xff55ffff),
    Color(0xff5555ff),
    Color(0xffff55ff),
  ];

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
    inColumnChildren.add(SelectableLinkify(
      onOpen: (link) => launch(link.url),
      text: chat.msg,
      options: const LinkifyOptions(humanize: false),
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

    inColumnChildren.add(SelectableLinkify(
      onOpen: (link) => launch(link.url),
      text: chat.msg,
      options: const LinkifyOptions(humanize: false),
    ));

    Color myColor = Colors.blue;
    if (!sameFrom && chat.from != null) {
      int code = 0;
      for (int i = 0; i < chat.from!.length; ++i) {
        code += chat.from!.codeUnitAt(i);
      }
      myColor = nickColors[code % nickColors.length];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sameFrom
            ? Container()
            : Text(
                chat.from!,
                style: TextStyle(color: myColor),
              ),
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
