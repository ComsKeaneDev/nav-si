import 'dart:async';
import 'dart:typed_data';
import '../speech_to_text/speech_to_text.dart';

enum MicrophoneSourceType {mobile, hardware}
enum MicrophoneState {uninitialized, ready, activeListening} // passiveListening, blocked

abstract class MicrophoneSource {
  MicrophoneState state = MicrophoneState.uninitialized;

  MicrophoneSourceType get type;
  SpeechToText speechToText = SpeechToText();

  Future<void> initialize() async {
    await speechToText.initialize();
  }

  Future<String?> processRecording(Uint8List recording) async {
    return await speechToText.processRecording(recording);
  }

  /// Start listening to voice.
  Future<void> startListening();

  /// Stop listening to voice.
  ///
  /// Parameters:
  ///   onResult: callback function when listening ends
  Future<void> stopListening(Future<void> Function(String result) onResult);

  /// Pause listening to voice.
  Future<void> pause();

  /// Resume listening to voice.
  Future<void> resume();

  Future<void> dispose() async {
    speechToText.dispose();
    state = MicrophoneState.uninitialized;
  }

}


