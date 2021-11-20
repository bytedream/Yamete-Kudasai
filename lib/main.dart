import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamete_kudasai/background.dart';
import 'package:yamete_kudasai/utils.dart';

import 'choose_audio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(MaterialApp(
    title: "Yamete Kudasai",
    theme: ThemeData.from(
      colorScheme: const ColorScheme.highContrastDark(
        primary: Color(0xFFFF0000),
        primaryVariant: Color(0xFFC20000),
        secondary: Colors.purple,
        surface: Colors.black,
        background: Colors.black12,
        onPrimary: Colors.white,
      ),
    ),
    home: YameteKudasai(),
  ));
}

class YameteKudasai extends StatefulWidget {
  @override
  _YameteKudasaiState createState() => _YameteKudasaiState();
}

class _YameteKudasaiState extends State<YameteKudasai> {
  @override
  Widget build(BuildContext context) {
    FlutterBackgroundService.initialize(initBackground, foreground: false);
    checkUpdate(context).then((value) => {
      if (!value) {
        checkFirstLaunch(context)
      }
    });

    return Scaffold(
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
            FutureBuilder(
              future: Sauce.sauceIndex(),
              builder: (BuildContext context, AsyncSnapshot<Map<String, Sauce>> snapshot) {
                if (!snapshot.hasData) {
                  return SizedBox.shrink();
                }
                return _buildAudioSettings(snapshot.data!);
              }
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateNotification(BuildContext context, String tag, String apkUrl) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: Text('Newer version is available ($tag)'),
      actions: [
        TextButton(
            onPressed: () async {
              await updateAPK(context, apkUrl);
              await showDialog(
                  context: context,
                  builder: (BuildContext context) => FutureProgressDialog(
                    updateAPK(context, apkUrl),
                    decoration: const BoxDecoration(
                        color: Colors.transparent
                    ),
                    message: const Text('Downloading update...'),
                  )
              );
            },
            child: const Text('Update')
        ),
        TextButton(
            onPressed: () async {
              if (await canLaunch('https://github.com/ByteDream/Yamete-Kudasai/releases/tag/$tag')) {
                await launch('https://github.com/ByteDream/Yamete-Kudasai/releases/tag/$tag');
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

  Widget _buildAudioSettings(Map<String, Sauce> sauceIndex) {
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
                  subtitle: Text(sauceIndex.entries.firstWhere((element) => element.key == targetAudio).value.alias),
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
                    final sauce = await Sauce.sauceIndex();
                    final audioFile = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                            builder: (BuildContext context) => ChooseAudio(targetAudio, sauce)
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

  Future<bool> checkUpdate(BuildContext context) async {
    final response = await http.get(Uri.https('api.github.com', 'repos/ByteDream/Yamete-Kudasai/releases/latest'))
        .timeout(const Duration(seconds: 5), onTimeout: () => http.Response.bytes([], 504));
    if (response.statusCode == 200) {
      final packageInfo = await PackageInfo.fromPlatform();
      final json =  (jsonDecode(response.body) as Map<String, dynamic>);
      final tag = json['tag_name'] as String;
      final apkUrl = json['assets'][0]['browser_download_url'] as String;
      if (int.parse(tag.substring(1).replaceAll('.', '')) > int.parse(packageInfo.version.replaceAll('.', ''))) {
        await showDialog(
            context: context,
            builder: (BuildContext context) => _buildUpdateNotification(context, tag, apkUrl)
        );
        return true;
      }
    }
    return false;
  }

  Future<void> updateAPK(BuildContext context, String apkUrl) async {
    ResultType result;
    if ((await Permission.storage.request()).isGranted) {
      final file = File('/storage/emulated/0/Download/${apkUrl.split('/').last}');
      final completer = Completer<void>();
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return FutureProgressDialog(
              completer.future,
              decoration: const BoxDecoration(
                  color: Colors.transparent
              ),
              message: const Text('Downloading update...'),
            );
          }
      );
      if (!(await file.exists())) {
        final resp = await http.get(Uri.parse(apkUrl));
        await file.writeAsBytes(resp.bodyBytes);
      }
      result = (await OpenFile.open(file.path)).type;
      completer.complete();
    } else {
      result = ResultType.error;
    }
    if (result != ResultType.done) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text('Failed to install update'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ok'),
                )
              ],
            );
          }
      );
    }
    Navigator.pop(context);
    // await file.delete();
  }

  Future<void> checkFirstLaunch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    final lastVersion = prefs.getString("version");
    final currentVersion = packageInfo.version;

    if ((lastVersion ?? "") != currentVersion) {
      final updateIndex = await Update.updatesIndex();
      await showDialog(
          context: context,
          builder: (BuildContext context) => _buildUpdateNotice(context, updateIndex[currentVersion]!)
      );
      await prefs.setString("version", currentVersion);
    }
  }

  Widget _buildUpdateNotice(BuildContext context, Update update) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: Text('Updated to ${update.version}'),
      actions: [
        TextButton(
          onPressed: () async {
            final url = 'https://github.com/ByteDream/Yamete-Kudasai/releases/tag/v${update.version}';
            if (await canLaunch(url)) {
              await launch(url);
            }
          },
          child: const Text('See more...')
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ok'),
        )
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(update.summary),
          Text('  » ${update.details.join("\n  » ")}')
        ],
      )
    );
  }

  Future<bool> isRunning() async {
    try {
      FlutterBackgroundService().sendData({'action': 'ping'});
      await FlutterBackgroundService().onDataReceived.first.timeout(const Duration(milliseconds: 500));
      return true;
    } on Exception {
      return false;
    }
  }
}
