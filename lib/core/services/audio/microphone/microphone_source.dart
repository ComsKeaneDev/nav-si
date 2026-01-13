import 'dart:async';
import 'dart:typed_data';
import '../speech_to_text.dart';

enum MicrophoneSourceType {mobile, hardware}

// currently just using passiveListening; but passiveListening = listening without keyword activation,
// activeListening = listening to respond after keyword activation
enum MicrophoneState {uninitialized, ready, passiveListening, activeListening, blocked} // blocked means speaker is speaking

abstract class MicrophoneSource {
  MicrophoneState get state;

  set state(MicrophoneState newState) {
    state = newState;
  }

  MicrophoneSourceType get type;
  SpeechToText speechToText = SpeechToText();

  Future<void> initialize() async {
    await speechToText.initialize();
  }

  String? processRecording(Uint8List recording) {
    return speechToText.processRecording(recording);
  }

  /// Start listening to voice.
  ///
  /// Parameters:
  ///   onResult: callback function when listening ends
  Future<void> startListening(Future<void> Function(String result) onResult);
  
  // bool checkListeningActivated(String recording) {
  //   String startRecordingPhrase = "hello";
  //
  //   bool listeningActivated = false;
  //
  //   if (state == MicrophoneState.passiveListening && recording.contains(startRecordingPhrase)) {
  //     textToSpeech.speak("On");
  //     state = MicrophoneState.activeListening;
  //     listeningActivated = true;
  //   }
  //
  //   return listeningActivated;
  //
  // }

  /// Stop listening to voice.
  Future<void> stopListening();

  /// Pause listening to voice.
  Future<void> pause();

  /// Resume listening to voice.
  Future<void> resume();

  Future<void> dispose() async {
    speechToText.dispose();
    state = MicrophoneState.uninitialized;
  }


}


