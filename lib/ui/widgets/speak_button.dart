import 'package:flutter/material.dart';
import '../../core/services/media_manager.dart';

/// A SpeakButton is always on-screen and is tapped/toggled to start and stop the microphone recording.
class SpeakButton extends StatefulWidget {

  final MediaManager mediaManager;
  final Future<void> Function()? onMicStarting;
  final Future<void> Function()? onMicStopped;

  const SpeakButton({super.key, required this.mediaManager, this.onMicStarting, this.onMicStopped});

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {

  static const IconData voiceIconOutline = IconData(0xf147, fontFamily: 'MaterialIcons'); // when not recording
  static const IconData voiceIconFilled = IconData(0xe35c, fontFamily: 'MaterialIcons'); // when recording

  bool _speaking = false;

  /// Callback function to handle the user pressing the speak button.
  Future<void> _onSpeakButtonPressed() async {
    // start recording
    if (!_speaking) {
      if (widget.onMicStarting != null) {
        await widget.onMicStarting!();
      }
      setState(() {
        _speaking = true;
      });
      await widget.mediaManager.startMicrophone();
    }
    // stop recording
    else {
      await widget.mediaManager.stopMicrophone();
      if (widget.onMicStopped != null) {
        await widget.onMicStopped!();
      }
      setState(() {
        _speaking = false;
      });
    }
  }

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
}
