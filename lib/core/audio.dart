import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// A Speaker provides text-to-speech abilities.
class Speaker {
  final FlutterTts textToSpeechObj = FlutterTts();

  Speaker();

  /// Speak aloud the given text after all previous speech finishes.
  ///
  /// Parameters:
  ///   text: text to speak
  Future<void> speak(String text) async {
    textToSpeechObj.awaitSpeakCompletion(true);
    await textToSpeechObj.speak(text);
  }
}

/// A Transcriber provides speech-to-text abilities.
class Transcriber {
  final SpeechToText speechToTextObj = SpeechToText();
  bool initialized = false;

  Transcriber();

  /// Start listening for voice.
  ///
  /// Parameters:
  ///   onResult: callback function when listening ends
  Future<void> startListening(void Function(SpeechRecognitionResult) onResult) async {
    if (!initialized) {
      await speechToTextObj.initialize(debugLogging: true);
      await Permission.microphone.request().isGranted;
      initialized = true;
    }
    await speechToTextObj.listen(onResult: onResult, listenOptions: SpeechListenOptions(onDevice: true, partialResults: false));
  }

  /// Stop listening for voice.
  Future<void> stopListening() async {
    await speechToTextObj.stop();
    // await speak(textToSpeech, "Off");
  }
}