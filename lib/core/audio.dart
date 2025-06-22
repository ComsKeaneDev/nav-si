import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

FlutterTts makeTextToSpeech() {
  return FlutterTts();
}

Future<void> speak(FlutterTts flutterTts, String text) async {
  flutterTts.awaitSpeakCompletion(true);
  await flutterTts.setVolume(1.0);
  await flutterTts.speak(text);
}

SpeechToText makeSpeechToText() {
  return SpeechToText();
}

Future<void> startListening(FlutterTts flutterTts, SpeechToText speechToText, void Function(SpeechRecognitionResult) onResult) async {
  await speechToText.initialize();
  await speak(flutterTts, "On");
  await speechToText.listen(onResult: onResult, listenOptions: SpeechListenOptions(partialResults: false));
}

Future<void> stopListening(FlutterTts flutterTts, SpeechToText speechToText) async {
  await speechToText.stop();
  await speak(flutterTts, "Off");
}