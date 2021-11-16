import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

final audio = {
  'Airi\'s first tutoring lesson': 'assets/audio/airis_first_tutoring_lesson.mp3',
  'The helpful pharmacist': 'assets/audio/the_helpful_pharmacist.mp3',
  'Yamete Kudasai': 'assets/audio/yamete_kudasai.mp3'
};

class ChooseAudio extends StatefulWidget {
  String _before;

  ChooseAudio(this._before, {Key? key}) : super(key: key);

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
            MapEntry<String, String> item = audio.entries.elementAt(index);
            if (index == _playIndex) {
              if (_playing == null) {
                play(item.value);
              } else {
                _playing!.stop().then((value) => play(item.value));
              }
            }
            return ListTile(
              leading: Radio(
                activeColor: Theme.of(context).colorScheme.secondary,
                value: item.value,
                groupValue: widget._before,
                onChanged: (String? value) {
                  setState(() {
                    widget._before = value!;
                  });
                }),
              title: Text(item.key),
              trailing: Icon(_playIndex == index ? Icons.stop_outlined : Icons.play_arrow_outlined),
              onTap: () {
                setState(() {
                  _playIndex = index;
                });
              },
            );
          },
          separatorBuilder: (BuildContext context, int index) => const Divider(),
          itemCount: audio.length
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

  void play(String path) async {
    _playing = await _player.play(path);
    _playing!.onPlayerCompletion.listen((event) {
      setState(() {
        _playIndex = -1;
      });
    });
  }
}
