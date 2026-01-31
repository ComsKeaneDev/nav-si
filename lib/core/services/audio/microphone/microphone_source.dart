import 'dart:async';
import 'dart:typed_data';
import '../speech_to_text/speech_to_text.dart';

/// Microphone enums.
enum MicrophoneSourceType {mobile, hardware}
enum MicrophoneState {uninitialized, ready, activeListening, disposed}
// other potential states: passiveListening (for wake-word detection), blocked (will call pause & resume)

/// A MicrophoneSource provides recording and transcription capabilities.
abstract class MicrophoneSource {

  MicrophoneState state = MicrophoneState.uninitialized;

  MicrophoneSourceType get type;
  SpeechToText speechToText = SpeechToText();

  /// Initialize microphone.
  Future<void> initialize() async {
    if (state != MicrophoneState.uninitialized) {
      throw StateError("Mobile microphone already initialized");
    }
    await speechToText.initialize();
  }

  /// Start listening to voice.
  Future<void> startListening() async {
    if (state == MicrophoneState.uninitialized) {
      await initialize();
    }
  }

  /// Stop listening to voice.
  ///
  /// Parameters:
  ///   onResult: callback function when listening ends
  Future<void> stopListening(Future<void> Function(String result) onResult);

  /// Transcribe voice recording.
  ///
  /// Parameters:
  ///   recording: recorded audio data
  Future<String?> transcribe(Uint8List recording) async {
    return await speechToText.processRecording(recording);
  }

  /// Temporarily stop listening to voice - not currently used.
  Future<void> pause() async {

  }

  /// Resume listening to voice - not currently used.
  Future<void> resume() async {

  }

  /// Dispose microphone.
  Future<void> dispose() async {
    speechToText.dispose();
    state = MicrophoneState.disposed;
  }

}


