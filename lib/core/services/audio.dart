import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../main.dart';

/// A Speaker provides text-to-speech capabilities.
class Speaker {
  final FlutterTts textToSpeechObj = FlutterTts();

  Speaker();

  /// Speak aloud the given text after all previous speech finishes.
  ///
  /// Parameters:
  ///   text: text to speak
  ///   noLongerListening (optional): true if want to turn listening flag off after speaking
  ///             (when processing previous voice recorded speech), false otherwise
  Future<void> speak(String text, {bool noLongerListening = false}) async {
    textToSpeechObj.awaitSpeakCompletion(true);
    if (!isListening || noLongerListening) {
      await textToSpeechObj.speak(text);
      isListening = false;
    }
  }

  /// Stop speaking aloud.
  Future<void> stop() async {
    await textToSpeechObj.stop();
  }
}

/// A Transcriber provides speech-to-text capabilities.
class Transcriber {
  final SpeechToText speechToTextObj = SpeechToText();
  bool initialized = false;

  Transcriber();

  /// Start listening to voice.
  ///
  /// Parameters:
  ///   onResult: callback function when listening ends
  Future<void> startListening(void Function(SpeechRecognitionResult) onResult) async {
    if (!initialized) {
      await speechToTextObj.initialize(debugLogging: true, onStatus: (status) {
        // if user presses record and then no audio is heard; indicate no longer listening
        if (status == "done") {
          isListening = false;
        }
      });
      await Permission.microphone.request().isGranted;
      initialized = true;
    }
    // partialResults = false not recognized when onDevice = true (fix in audio.dart)
    await speechToTextObj.listen(onResult: onResult, listenOptions: SpeechListenOptions(onDevice: true, partialResults : false));
  }

  /// Stop listening to voice.
  Future<void> stopListening() async {
    await speechToTextObj.stop();
    // await speak(textToSpeech, "Off");
  }
}