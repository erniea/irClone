import 'dart:developer';

import 'package:badges/badges.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:irclone/structure.dart';
import 'package:bubble/bubble.dart';
import 'package:url_launcher/url_launcher.dart';

class ChannelView extends StatefulWidget {
  const ChannelView(
      {Key? key,
      required this.getPastLog,
      required this.channel,
      required this.controller})
      : super(key: key);
  final Function getPastLog;
  final Channel channel;
  final ScrollController controller;
  @override
  State<ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends State<ChannelView> {
  List<Widget> chatViewItems = [];

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(() {
      if (widget.controller.position.pixels ==
              widget.controller.position.maxScrollExtent &&
          widget.channel.chats.isNotEmpty) {
        widget.getPastLog(widget.channel.chats[0].logId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    chatViewItems = _createChatView(context, widget.channel.chats);

    return ListView.builder(
      controller: widget.controller,
      itemBuilder: (c, i) => chatViewItems[chatViewItems.length - i - 1],
      itemCount: chatViewItems.length,
      reverse: true,
    );
  }

  List<Widget> _createChatView(context, chats) {
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
          padding: const BubbleEdges.all(5),
          alignment: Alignment.center,
          color: const Color.fromRGBO(212, 234, 244, 1.0),
          child: Text(
            DateFormat.yMd().format(time),
            style: const TextStyle(fontSize: 12),
          ),
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
  final TextStyle chipStyle =
      kIsWeb ? const TextStyle() : const TextStyle(fontSize: 10);
  final TextStyle timeStyle = kIsWeb
      ? const TextStyle(fontSize: 10, color: Colors.grey)
      : const TextStyle(fontSize: 8, color: Colors.grey);
  final TextStyle textStyle =
      kIsWeb ? const TextStyle() : const TextStyle(fontSize: 18);

  @override
  Widget build(BuildContext context) {
    var time = DateTime.fromMillisecondsSinceEpoch(chat.timestamp);
    return chat.from == null
        ? _createEmptyBubbleMsg(context, time)
        : chat.myMsg
            ? _createMyBubbleMsg(context, time, sameFrom, sameTime)
            : _createOtherBubbleMsg(context, time, sameFrom, sameTime);
  }

  Widget _createEmptyBubbleMsg(context, time) {
    return Bubble(
      stick: true,
      margin: const BubbleEdges.only(top: 10),
      padding: const BubbleEdges.all(3),
      color: const Color.fromRGBO(212, 234, 244, 1.0),
      child: Text(
        chat.msg,
        textAlign: TextAlign.center,
        style: chipStyle,
      ),
    );
  }

  Widget _createMyBubbleMsg(context, time, sameFrom, sameTime) {
    List<Widget> inColumnChildren = [];

    if (!sameTime) {
      inColumnChildren.add(Text(
        DateFormat.Hm().format(time),
        textAlign: TextAlign.right,
        style: timeStyle,
      ));
    }
    inColumnChildren.add(SelectableLinkify(
      onOpen: (link) => launch(link.url),
      text: chat.msg,
      options: const LinkifyOptions(humanize: false),
      style: textStyle,
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Bubble(
          margin: BubbleEdges.only(bottom: 4, right: sameTime ? 8 : 0),
          padding: const BubbleEdges.all(10),
          alignment: Alignment.topRight,
          nip: sameFrom && sameTime ? BubbleNip.no : BubbleNip.rightTop,
          color: const Color.fromRGBO(225, 255, 199, 1.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: inColumnChildren),
        ),
      ],
    );
  }

  Widget _createOtherBubbleMsg(context, time, sameFrom, sameTime) {
    List<Widget> inColumnChildren = [];
    if (!sameTime) {
      inColumnChildren.add(Text(
        DateFormat.Hm().format(time),
        textAlign: TextAlign.left,
        style: timeStyle,
      ));
    }

    inColumnChildren.add(SelectableLinkify(
      onOpen: (link) => launch(link.url),
      text: chat.msg,
      options: const LinkifyOptions(humanize: false),
      style: textStyle,
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
            : Chip(
                label: SelectableText(
                  chat.from!,
                  style: chipStyle,
                ),
                backgroundColor: myColor.withAlpha(33),
              ),
        Bubble(
          margin: BubbleEdges.only(bottom: 4, left: sameTime ? 8 : 0),
          padding: const BubbleEdges.all(10),
          alignment: Alignment.topLeft,
          nip: sameFrom && sameTime ? BubbleNip.no : BubbleNip.leftTop,
          color: chat.mentioned ? Colors.amberAccent : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: inColumnChildren,
          ),
        ),
      ],
    );
  }
}

class ChannelDrawer extends StatefulWidget {
  const ChannelDrawer({
    Key? key,
    required this.servers,
    required this.channels,
    required this.onChannelSelected,
    required this.sendAddChannelToServer,
    required this.sendAddServer,
    required this.currentServer,
    required this.currentChannel,
  }) : super(key: key);
  final Map<int, Server> servers;
  final List<ChannelForList> channels;
  final Function onChannelSelected;
  final Function sendAddChannelToServer;
  final Function sendAddServer;
  final int currentServer;
  final String currentChannel;
  @override
  State<ChannelDrawer> createState() => _ChannelDrawerState();
}

class _ChannelDrawerState extends State<ChannelDrawer> {
  @override
  Widget build(BuildContext context) {
    List<Widget> widgetList = [];

    widgetList.add(DrawerHeader(
      child: Column(
        children: [
          Expanded(child: Container()),
          Row(
            children: [
              Expanded(child: Container()),
              ElevatedButton(
                child: const Icon(Icons.add_link),
                onPressed: () {
                  Navigator.pop(context);
                  _popupAddServer(context);
                },
                style: ElevatedButton.styleFrom(shape: const CircleBorder()),
              ),
            ],
          ),
        ],
      ),
    ));

    int prevServerId = -1;
    for (ChannelForList c in widget.channels) {
      if (c.serverId != prevServerId) {
        prevServerId = c.serverId;

        widgetList.add(ListTile(
          tileColor: Theme.of(context).focusColor,
          title: Row(children: [
            Expanded(child: Text(widget.servers[c.serverId]!.serverName)),
            ElevatedButton(
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.pop(context);
                _popupAddChannel(context, c.serverId,
                    widget.servers[c.serverId]!.serverName);
              },
              style: ElevatedButton.styleFrom(shape: const CircleBorder()),
            ),
          ]),
        ));
      }
      widgetList.add(ListTile(
        title: Row(children: [
          Text(
            c.channelName,
            style: TextStyle(
                fontWeight: c.serverId == widget.currentServer &&
                        c.channelName == widget.currentChannel
                    ? FontWeight.bold
                    : FontWeight.normal),
          ),
          c.newMsg > 0
              ? Badge(
                  badgeContent: Text(c.newMsg.toString()),
                  badgeColor: c.toMe ? Colors.red : Colors.amber,
                )
              : Container(),
        ]),
        onTap: () {
          widget.onChannelSelected(c.serverId, c.channelName);
          setState(() {
            c.newMsg = 0;
            c.toMe = false;
          });

          Navigator.pop(context);
        },
      ));
    }

    return Drawer(
        child: ListView.builder(
      itemBuilder: (context, i) => widgetList[i],
      itemCount: widgetList.length,
    ));
  }

  void _popupAddServer(context) {
    showDialog(
        context: context,
        builder: (context) {
          return ServerSettingDlg(
            sendAddServer: widget.sendAddServer,
          );
        });
  }

  void _popupAddChannel(context, serverId, serverName) {
    showDialog(
        context: context,
        builder: (context) {
          return ChannelSettingDlg(
            serverName: serverName,
            serverId: serverId,
            sendAddChannelToServer: widget.sendAddChannelToServer,
          );
        });
  }
}

class ServerSettingDlg extends StatefulWidget {
  const ServerSettingDlg({Key? key, required this.sendAddServer})
      : super(key: key);

  final Function sendAddServer;
  @override
  _ServerSettingDlgState createState() => _ServerSettingDlgState();
}

class _ServerSettingDlgState extends State<ServerSettingDlg> {
  TextEditingController serverName = TextEditingController(),
      serverAddress = TextEditingController(text: "evans.uriirc.org"),
      serverPort = TextEditingController(text: "16661"),
      nickName = TextEditingController(),
      realName = TextEditingController();
  bool useSSL = true;

  @override
  void dispose() {
    serverName.dispose();
    serverAddress.dispose();
    serverPort.dispose();
    nickName.dispose();
    realName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      title: const Text("Add a Server"),
      content: Form(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Server"),
            TextFormField(
              controller: serverName,
              decoration: const InputDecoration(labelText: "Server Name"),
            ),
            TextFormField(
              controller: serverAddress,
              decoration: const InputDecoration(labelText: "Server Address"),
            ),
            TextFormField(
              controller: serverPort,
              decoration: const InputDecoration(labelText: "Server Port"),
            ),
            Row(
              children: [
                const Expanded(child: Text("Use SSL")),
                Switch(
                  value: useSSL,
                  onChanged: (c) {
                    setState(() {
                      useSSL = c;
                    });
                  },
                )
              ],
            ),
            const Text("User"),
            TextFormField(
              controller: nickName,
              decoration: const InputDecoration(labelText: "Nickname"),
            ),
            TextFormField(
              controller: realName,
              decoration: const InputDecoration(labelText: "Real Name"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel")),
        ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.sendAddServer(
                serverName.text,
                serverAddress.text,
                serverPort.text,
                useSSL,
                nickName.text,
                realName.text,
              );
            },
            child: const Text("OK"))
      ],
    );
  }
}

class ChannelSettingDlg extends StatefulWidget {
  const ChannelSettingDlg(
      {Key? key,
      required this.serverName,
      required this.serverId,
      required this.sendAddChannelToServer})
      : super(key: key);
  final String serverName;
  final int serverId;
  final Function sendAddChannelToServer;
  @override
  _ChannelSettingDlgState createState() => _ChannelSettingDlgState();
}

class _ChannelSettingDlgState extends State<ChannelSettingDlg> {
  final TextEditingController _controller = TextEditingController(text: "#");
  final _formKey = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      title: Text("Add a Channel to " + widget.serverName),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _controller,
            validator: (s) {
              if (s == null || s.isEmpty) {
                return "채널 이름을 입력해 주세요.";
              }
              if (s[0] != '#') {
                return "채널 이름은 #으로 시작해야 합니다.";
              }
              if (s.length == 1) {
                return "채널 이름을 입력해 주세요";
              }
              return null;
            },
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel")),
        ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context);
                widget.sendAddChannelToServer(
                    widget.serverId, _controller.text);
              }
            },
            child: const Text("OK"))
      ],
    );
  }
}
