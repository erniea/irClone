import 'dart:developer';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:irclone/irctalk.dart';

class WebSocketTask extends TaskHandler {
  ReceivePort? receivePort = ReceivePort();
  IrcTalk? ircTalk;
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    ircTalk = IrcTalk(
      storeAuth: (authKey) => _storeAuth(sendPort, authKey),
      msgHandler: (event) => _msgHandler(sendPort, event),
    );
    ircTalk?.createWebSocketChannel();

    receivePort?.listen(_taskHandler);

    sendPort?.send(receivePort?.sendPort);
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // You can use the clearAllData function to clear all the stored data.
    await FlutterForegroundTask.clearAllData();
  }

  void _storeAuth(sendPort, authKey) {
    var auth = {"taskType": "storeAuth", "authKey": authKey};

    sendPort?.send(auth);
  }

  void _taskHandler(event) {
    switch (event["taskType"]) {
      case "init":
        ircTalk?.initWebSocket(event["accessToken"], event["authKey"]);
        break;
      case "send":
        ircTalk?.sendMessage(event["server"], event["channel"], event["text"]);
        break;
      case "getPastLogs":
        ircTalk?.sendGetPastLogs(
            event["server"], event["channel"], event["lastLogId"]);
        break;
      default:
        break;
    }
  }

  void _msgHandler(sendPort, event) {
    var json = {"taskType": "raw", "data": event};
    sendPort?.send(json);
  }
}
