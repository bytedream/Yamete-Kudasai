import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamete_kudasai/utils.dart';

class ChooseAudio extends StatefulWidget {
  String _before;
  final Map<String, Sauce> _sauce;

  ChooseAudio(this._before, this._sauce, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ChooseAudioState();
}

class _ChooseAudioState extends State<ChooseAudio> {
  final _player = AudioCache(prefix: '');
  int _playIndex = -1;
  AudioPlayer? _playing;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, widget._before);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose audio')
        ),
        body: ListView.separated(
            itemBuilder: (BuildContext context, int index) {
              MapEntry<String, Sauce> item = widget._sauce.entries.elementAt(index);
              if (index == _playIndex) {
                if (_playing == null) {
                  play(item.key);
                } else {
                  _playing!.stop().then((value) => play(item.key));
                }
              }
              return ListTile(
                leading: Radio(
                    activeColor: Theme.of(context).colorScheme.secondary,
                    value: item.value.filepath,
                    groupValue: widget._before,
                    onChanged: (String? value) {
                      setState(() {
                        widget._before = value!;
                      });
                    }),
                title: Text(item.value.alias),
                trailing: IconButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) => _buildSauceInfo(context, item.value)
                      );
                    },
                    icon: Icon(Icons.info)
                ),
                onTap: () {
                  setState(() {
                    _playIndex = index;
                  });
                },
              );
            },
            separatorBuilder: (BuildContext context, int index) => const Divider(),
            itemCount: widget._sauce.length
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_playing != null) {
      _playing!.stop();
    }
    super.dispose();
  }

  Widget _buildSauceInfo(BuildContext context, Sauce sauce) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: Text('${sauce.alias} sauce'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Name: ${sauce.name}'),
          Text('Season: ${sauce.season ?? "?"}'),
          Text('Episode: ${sauce.episode ?? "?"}'),
          Text('Audio time: ${sauce.from ?? "?"} - ${sauce.to ?? "?"}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final search = 'https://hentaihaven.com/?s=${sauce.name.replaceAll(" ", "+")}';
            if (await canLaunch(search)) {
              await launch(search);
            }
          },
          child: const Text('Search online')
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Ok')
        )
      ],
    );
  }

  void play(String path) async {
    _playing = await _player.play(path);
    _playing!.onPlayerCompletion.listen((event) {
      setState(() {
        _playIndex = -1;
      });
    });
  }
}
