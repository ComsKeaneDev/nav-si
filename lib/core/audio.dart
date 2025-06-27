import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Create a text to speech object with volume 1.0.
FlutterTts makeTextToSpeech() {
  FlutterTts textToSpeech = FlutterTts();
  textToSpeech.setVolume(1.0);
  return textToSpeech;
}

/// Speak aloud the given text after all previous speech finishes.
///
/// Parameters:
///   textToSpeech: text-to-speech object
///   text: text to speak
Future<void> speak(FlutterTts flutterTts, String text) async {
  flutterTts.awaitSpeakCompletion(true);
  await flutterTts.speak(text);
}

/// Make a speech to text object.
SpeechToText makeSpeechToText() {
  return SpeechToText();
}

/// Start listening for voice with audio confirmation.
///
/// Parameters:
///   textToSpeech: text-to-speech object
///   speechToText: speech-to-text object
///   onResult: callback function when listening ends
Future<void> startListening(FlutterTts textToSpeech, SpeechToText speechToText, void Function(SpeechRecognitionResult) onResult) async {
  await speechToText.initialize();
  await speak(textToSpeech, "On");
  await speechToText.listen(onResult: onResult, listenOptions: SpeechListenOptions(partialResults: false));
}

/// Stop listening for voice with audio confirmation.
///
/// Parameters:
///   textToSpeech: text-to-speech object
///   speechToText: speech-to-text object
Future<void> stopListening(FlutterTts textToSpeech, SpeechToText speechToText) async {
  await speechToText.stop();
  await speak(textToSpeech, "Off");
}