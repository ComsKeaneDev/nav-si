import 'package:flutter_tts/flutter_tts.dart';

/// A SpeakerConfig provides the parameters needed to initialize a Speaker.
class SpeakerConfig {

  String language;
  double volume; // 0.0 (silent) to 1.0 (loudest)
  double rate; // 0.0 (slowest) to 1.0 (fastest)

  SpeakerConfig({required this.language, required this.volume, required this.rate});

}

/// A Speaker provides text-to-speech capabilities using the mobile speaker.
class Speaker {

  late final FlutterTts textToSpeechObj;

  Speaker({required String language, required double volume, required double rate}) {
    textToSpeechObj = FlutterTts();
    textToSpeechObj.setLanguage(language);
    textToSpeechObj.setVolume(volume);
    textToSpeechObj.setSpeechRate(rate);
  }

  /// Speak the given text aloud.
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


  /// Set the speaker's language.
  ///
  /// Parameters:
  ///   language: the new language
  void setLanguage(String language) {
    textToSpeechObj.setLanguage(language);
  }

  /// Set the speaker's volume.
  ///
  /// Parameters:
  ///   volume: the new volume in the range of 0.0 (silent) to 1.0 (loudest)
  void setVolume(double volume) {
    textToSpeechObj.setVolume(volume);
  }

  /// Set the speaker's rate.
  ///
  /// Parameters:
  ///   rate: the new rate in the range of 0.0 (slowest) to 1.0 (fastest)
  void setSpeechRate(double rate) {
    textToSpeechObj.setSpeechRate(rate);
  }
}