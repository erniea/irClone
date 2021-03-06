import 'package:flutter/material.dart';

class ServerSettingDlg extends StatefulWidget {
  const ServerSettingDlg({Key? key, required this.sendAddServer})
      : super(key: key);

  final Function sendAddServer;
  @override
  _ServerSettingDlgState createState() => _ServerSettingDlgState();
}

class _ServerSettingDlgState extends State<ServerSettingDlg> {
  final TextEditingController _serverName = TextEditingController(),
      _serverAddress = TextEditingController(text: "evans.uriirc.org"),
      _serverPort = TextEditingController(text: "16661"),
      _nickName = TextEditingController(),
      _realName = TextEditingController();
  bool useSSL = true;

  @override
  void dispose() {
    _serverName.dispose();
    _serverAddress.dispose();
    _serverPort.dispose();
    _nickName.dispose();
    _realName.dispose();
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
              controller: _serverName,
              decoration: const InputDecoration(labelText: "Server Name"),
            ),
            TextFormField(
              controller: _serverAddress,
              decoration: const InputDecoration(labelText: "Server Address"),
            ),
            TextFormField(
              controller: _serverPort,
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
              controller: _nickName,
              decoration: const InputDecoration(labelText: "Nickname"),
            ),
            TextFormField(
              controller: _realName,
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
                _serverName.text,
                _serverAddress.text,
                _serverPort.text,
                useSSL,
                _nickName.text,
                _realName.text,
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
                return "?????? ????????? ????????? ?????????.";
              }
              if (s[0] != '#') {
                return "?????? ????????? #?????? ???????????? ?????????.";
              }
              if (s.length == 1) {
                return "?????? ????????? ????????? ?????????";
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
