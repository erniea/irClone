import 'dart:developer';
import 'dart:html';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutterfire_ui/auth.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyCybtkNwPRTD4Gs4sm4uV-4alupyuG5LOA",
          authDomain: "irclone.firebaseapp.com",
          projectId: "irclone",
          storageBucket: "irclone.appspot.com",
          messagingSenderId: "349437488054",
          appId: "1:349437488054:web:4e47dc40075d7d916fef17",
          measurementId: "G-PS2W9E5BHF"));
  runApp(const IrClone());
}

class IrClone extends StatelessWidget {
  const IrClone({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "title",
      home: AuthGate(key: key),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String str = "test";
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          return snapshot.hasData
              ? ChatMain(
                  title: "title",
                  channel: WebSocketChannel.connect(Uri.parse("ws://url")),
                )
              : Center(
                  child: Column(
                    children: [
                      TextButton(
                          onPressed: () async {
                            var googleSignIn = GoogleSignIn(
                                clientId:
                                    "349437488054-apko0h450gts1nqpfe9g085qrkgn2b1h.apps.googleusercontent.com");

                            var user = await googleSignIn.signIn();
                            var auth = await user?.authentication;
                            var cred = GoogleAuthProvider.credential(
                                accessToken: auth?.accessToken,
                                idToken: auth?.idToken);
                            //log(auth?.accessToken as String);
                            await FirebaseAuth.instance
                                .signInWithCredential(cred);
                          },
                          child: Text(str)),
                    ],
                  ),
                );
          /*const SignInScreen(
                  providerConfigs: [
                    GoogleProviderConfiguration(
                        clientId:
                            "349437488054-apko0h450gts1nqpfe9g085qrkgn2b1h.apps.googleusercontent.com")
                  ],
                );
                */
        });
  }
}

class ChatMain extends StatefulWidget {
  final String title;
  final WebSocketChannel channel;

  const ChatMain({Key? key, required this.title, required this.channel})
      : super(key: key);

  @override
  _ChatMainState createState() => _ChatMainState();
}

class _ChatMainState extends State<ChatMain> {
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
            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: const Text("sign out"),
            ),
            TextButton(onPressed: () {}, child: const Text("msg")),
            //Text(FirebaseAuth.instance.currentUser?.tenantId as String),
            Form(
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Send a message'),
              ),
            ),
            Text(""),
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
