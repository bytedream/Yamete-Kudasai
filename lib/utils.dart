import 'dart:convert';

import 'package:flutter/services.dart';

class Sauce {
  final String filepath;
  final String alias;
  final String name;
  final String? season;
  final String? episode;
  final String? from;
  final String? to;

  const Sauce(this.filepath,
      this.alias,
      this.name,
      this.season,
      this.episode,
      this.from,
      this.to);

  static Future<Map<String, Sauce>> sauceIndex() async {
    final sauceJson = await rootBundle.loadString('assets/sauce.json');
    Map<String, dynamic> sauce = jsonDecode(sauceJson);

    Map<String, Sauce> sauceIndex = new Map();

    for (MapEntry<String, dynamic> entry in sauce.entries) {
      final value = entry.value as Map<String, dynamic>;
      sauceIndex[entry.key] = Sauce(
        entry.key,
        value['alias'],
        value['name'],
        value['season'],
        value['episode'],
        value['from'],
        value['to']
      );
    }

    return sauceIndex;
  }
}

class Update {
  final String version;
  final String summary;
  final List<String> details;

  const Update(this.version,
      this.summary,
      this.details);

  static Future<Map<String, Update>> updatesIndex() async {
    final updatesJson = await rootBundle.loadString('assets/updates.json');
    Map<String, dynamic> updates = jsonDecode(updatesJson);

    Map<String, Update> updatesIndex = new Map();

    for (MapEntry<String, dynamic> entry in updates.entries) {
      final value = entry.value as Map<String, dynamic>;
      updatesIndex[entry.key] = Update(
        entry.key,
        value['summary'],
        (value['details'] as List).cast<String>()
      );
    }

    return updatesIndex;
  }
}
