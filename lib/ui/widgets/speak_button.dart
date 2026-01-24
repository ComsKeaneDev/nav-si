import 'package:flutter/material.dart';

import '../../core/services/media_manager.dart';

class SpeakButton extends StatefulWidget {
  final MediaManager mediaManager;

  const SpeakButton({super.key, required this.mediaManager});

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {

  final IconData voiceIconOutline = IconData(0xf147, fontFamily: 'MaterialIcons');
  final IconData voiceIconFilled = IconData(0xe35c, fontFamily: 'MaterialIcons');

  bool _speaking = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      label: "Microphone",
      button: true,
      hint: _speaking ? "Activate to stop recording" : "Activate to start recording",
      child: FloatingActionButton(
        onPressed: _onSpeakButtonPressed,
        backgroundColor: _speaking ? Colors.deepPurple.shade200 : Colors.deepPurple.shade100,
        child: _speaking ? Icon(voiceIconFilled) : Icon(voiceIconOutline),
      ),
    );
  }

  Future<void> _onSpeakButtonPressed() async {

    if (!_speaking) {
      setState(() {
        _speaking = true;
      });
      await widget.mediaManager.startMicrophone();
    }
    else {
      setState(() {
        _speaking = false;
      });
      await widget.mediaManager.stopMicrophone();
    }
  }
}
