import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:port_update/port_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

final actions = {
  UpdateAction.batteryCharging: "Battery charging",
  UpdateAction.batteryDischarging: "Battery discharging",
  UpdateAction.batteryFull: "Battery full",
  UpdateAction.headphoneConnected: "Headphone connected",
  UpdateAction.headphoneDisconnected: "Headphone disconnected",
};

final _player = AudioCache(prefix: '');
final _portUpdate = PortUpdate();

String generateEventData(SharedPreferences sharedPreferences) {
  Map<String, String> data = {};

  for (var action in UpdateAction.values) {
    if (sharedPreferences.getBool("${action.index}.activated") ?? true) {
      data[action.index.toString()] = sharedPreferences.getString("${action.index}.target") ?? "assets/audio/yamete_kudasai.mp3";
    }
  }
  return jsonEncode(data);
}

void initBackground() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterBackgroundService().setNotificationInfo(
    title: "Yamete Kudasai",
    content: "Preparing",
  );

  Map<UpdateAction, String>? data;
  int running = 0;

  StreamSubscription<UpdateAction?>? sub = _portUpdate.stream.listen((event) async {
    data ??= (jsonDecode(generateEventData(await SharedPreferences.getInstance())) as Map<String, dynamic>)
        .map((key, value) => MapEntry(UpdateAction.values.elementAt(int.parse(key)), value as String));
    if (data!.containsKey(event!)) {
      final player = await _player.play(data![event]!);
      running++;
      FlutterBackgroundService().setNotificationInfo(
        title: 'Yamete Kudasai',
        content: 'Dispatching ${actions.values.elementAt(event.index).toLowerCase()} event'
      );
      await player.onPlayerCompletion.first;
      if (--running == 0) {
        FlutterBackgroundService().setNotificationInfo(
          title: 'Yamete Kudasai',
          content: 'Running'
        );
      }
    }
  });

  FlutterBackgroundService().setNotificationInfo(
    title: "Yamete Kudasai",
    content: "Running",
  );

  FlutterBackgroundService().onDataReceived.listen((event) async {
    switch (event!['action']) {
      case 'stop':
        await sub.cancel();
        FlutterBackgroundService().stopBackgroundService();
        break;
      case 'data':
        data = (jsonDecode(event['value']) as Map<String, dynamic>).map((key, value) {
          return MapEntry(UpdateAction.values.elementAt(int.parse(key)), value.toString());
        });
        break;
      case 'ping':
        FlutterBackgroundService().sendData({'action': 'pong'});
        break;
    }
  });
}
