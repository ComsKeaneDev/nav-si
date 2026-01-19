import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';

class SpeakerConfig {

  String language;
  double volume;
  double rate;

  SpeakerConfig({required this.language, required this.volume, required this.rate});

}

/// A Speaker provides text-to-speech capabilities.
class Speaker {
  late final FlutterTts textToSpeechObj;

  Speaker({required String language, required double volume, required double rate}) {
    textToSpeechObj = FlutterTts();
    textToSpeechObj.setLanguage(language);
    textToSpeechObj.setVolume(volume);
    textToSpeechObj.setSpeechRate(rate);
  }

  /// Speak aloud the given text.
  ///
  /// Parameters:
  ///   text: text to speak
  Future<void> speak(String text) async {
    textToSpeechObj.awaitSpeakCompletion(true);
    await textToSpeechObj.speak(text);
  }

  /// Stop speaking aloud.
  Future<void> stop() async {
    await textToSpeechObj.stop();
  }
}