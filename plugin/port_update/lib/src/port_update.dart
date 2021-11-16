import 'package:flutter/services.dart';

enum UpdateAction {
  unknown,
  batteryCharging,
  batteryDischarging,
  batteryFull,
  headphoneConnected,
  headphoneDisconnected
}

class PortUpdate {
  static const channel = "port/stream";

  final _channel = const EventChannel(channel);

  Stream<UpdateAction?> get stream => _channel.receiveBroadcastStream().map((event) => UpdateAction.values.elementAt(event));
}
