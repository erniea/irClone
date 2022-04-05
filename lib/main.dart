import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const IrClone());

class IrClone extends StatelessWidget {
  const IrClone({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const title = 'WebSocket Demo';
    return MaterialApp(
      title: title,
      home: IrCloneMain(
        title: title,
        channel: WebSocketChannel.connect(
            //Uri.parse('wss://beta.ircta.lk:443/irctalk')),
            Uri.parse('ws://localhost:9998')),
      ),
    );
  }
}

class IrCloneMain extends StatefulWidget {
  final String title;
  final WebSocketChannel channel;

  const IrCloneMain({Key? key, required this.title, required this.channel})
      : super(key: key);

  @override
  _IrCloneMainState createState() => _IrCloneMainState();
}

class _IrCloneMainState extends State<IrCloneMain> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Form(
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Send a message'),
              ),
            ),
            StreamBuilder(
              stream: widget.channel.stream,
              builder: (context, snapshot) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(snapshot.hasData ? '${snapshot.data}' : ''),
                );
              },
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Send message',
        child: const Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      widget.channel.sink.add(_controller.text);
    }
  }

  @override
  void dispose() {
    widget.channel.sink.close();
    super.dispose();
  }
}
