import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamete_kudasai/background.dart';

import 'choose_audio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(YameteKudasai());
}

class YameteKudasai extends StatefulWidget {
  @override
  _YameteKudasaiState createState() => _YameteKudasaiState();
}

class _YameteKudasaiState extends State<YameteKudasai> {
  @override
  Widget build(BuildContext context) {
    http.get(Uri.https('api.github.com', 'repos/ByteDream/yamete_kudasai/releases/latest'))
        .timeout(const Duration(seconds: 5), onTimeout: () => http.Response.bytes([], 504)).then((response) async {
      if (response.statusCode == 200) {
        final packageInfo = await PackageInfo.fromPlatform();
        final tag = (jsonDecode(response.body) as Map<String, dynamic>)['tag_name'] as String;
        if (int.parse(tag.substring(1).replaceAll('.', '')) > int.parse(packageInfo.version.replaceAll('.', ''))) {
          showDialog(
            context: context,
            builder: (BuildContext context) => _buildUpdateNotification(context, tag)
          );
        }
      }
    });
    FlutterBackgroundService.initialize(initBackground, foreground: false);

    return MaterialApp(
      title: "Yamete Kudasai",
      theme: ThemeData.from(
        colorScheme: const ColorScheme.highContrastDark(
          primary: Color(0xFFFF0000),
          primaryVariant: Color(0xFFC20000),
          secondary: Colors.purple,
          surface: Colors.black,
          background: Colors.black26,
          onPrimary: Colors.white,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Yamete Kudasai'),
        ),
        body: Center(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      child: Row(
                        children: const [
                          Text("Start"),
                          Icon(Icons.play_arrow_outlined)
                        ],
                      ),
                      onPressed: () async {
                        WidgetsFlutterBinding.ensureInitialized();
                        FlutterBackgroundService().sendData({'action': 'stop'});
                        while (await isRunning()) {}
                        FlutterBackgroundService.initialize(initBackground);
                      },
                    ),
                    ElevatedButton(
                      child: Row(
                        children: const [
                          Text("Stop"),
                          Icon(Icons.stop_outlined)
                        ],
                      ),
                      onPressed: () {
                        FlutterBackgroundService().sendData({'action': 'stop'});
                      },
                    )
                  ],
                ),
              ),
              const Divider(color: Colors.white),
              _buildAudioSettings()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateNotification(BuildContext context, String tag) {
    return AlertDialog(
      title: Text('Newer version is available ($tag)'),
      actions: [
        TextButton(
          onPressed: () async {
            if (await canLaunch('https://github.com/ByteDream/yamete_kudasai/releases/tag/$tag')) {
              await launch('https://github.com/ByteDream/yamete_kudasai/releases/tag/$tag');
            }
          },
          child: const Text('Show new release')
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('No thanks :)')
        )
      ],
    );
  }

  Widget _buildAudioSettings() {
    return FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (BuildContext context, AsyncSnapshot<SharedPreferences> snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final prefs = snapshot.data!;
          final entries = actions.entries;

          return ListView.builder(
            shrinkWrap: true,
            itemCount: actions.length,
            itemBuilder: (BuildContext context, int index) {
              final item = entries.elementAt(index);

              final activatedKey = "${item.key.index}.activated";
              final targetKey = "${item.key.index}.target";

              final activatedAudio = prefs.getBool(activatedKey) ?? true;
              final targetAudio = prefs.getString(targetKey) ?? "assets/audio/yamete_kudasai.mp3";

              return ListTile(
                title: Text(item.value),
                subtitle: Text(audio.entries.firstWhere((element) => element.value == targetAudio).key),
                trailing: Switch(
                  activeColor: Theme.of(context).colorScheme.secondary,
                  value: prefs.getBool(activatedKey) ?? true,
                  onChanged: (bool newValue) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    prefs.setBool(activatedKey, !activatedAudio);
                    FlutterBackgroundService().sendData({'action': 'data', 'value': generateEventData(prefs)});
                    setState(() {});
                  }),
                onTap: () async {
                  final audioFile = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                        builder: (BuildContext context) => ChooseAudio(targetAudio)
                    )
                  );
                  if (audioFile != null && audioFile != targetAudio) {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    prefs.setString(targetKey, audioFile);
                    FlutterBackgroundService().sendData({'action': 'data', 'value': generateEventData(prefs)});
                    setState(() {});
                  }
                },
              );
            }
          );
        }
    );
  }

  Future<bool> isRunning() async {
    try {
      FlutterBackgroundService().sendData({'action': 'ping'});
      await FlutterBackgroundService().onDataReceived.first.timeout(const Duration(milliseconds: 500));
      return true;
    } on Exception catch (e) {
      return false;
    }
  }
}
