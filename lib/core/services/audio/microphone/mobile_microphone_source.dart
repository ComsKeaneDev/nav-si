import 'dart:async';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'microphone_source.dart';

class MobileMicrophoneSource extends MicrophoneSource {
  late final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  Future<void> Function(String result)? _onListeningResult;

  final List<Uint8List> _audioBuffer = [];
  Timer? _processingTimer;
  static const int _bufferDurationMs = 2000; // process every 2 seconds

  MicrophoneState _state = MicrophoneState.uninitialized;
  Stream<Uint8List>? _stream;

  MobileMicrophoneSource();

  @override MicrophoneState get state => _state;
  @override MicrophoneSourceType get type => MicrophoneSourceType.mobile;
  bool get isListening => _state == MicrophoneState.passiveListening;

  @override
  Future<void> initialize() async {

    if (state != MicrophoneState.uninitialized) {
      return;
    }

    await super.initialize();

    await Permission.microphone
        .request()
        .isGranted;

    _state = MicrophoneState.ready;

  }

  @override
  Future<void> startListening(Future<void> Function(String result) onListeningResult) async {
    if (_state == MicrophoneState.uninitialized) {
      await initialize();
    }

    _onListeningResult = onListeningResult;

    // if (_state == MicrophoneState.passiveListening) {
    //   return;
    // }

    _state = MicrophoneState.passiveListening;

    const sampleRate = 16000;
    const encoder = AudioEncoder.pcm16bits;

    const config = RecordConfig(
      encoder: encoder,
      sampleRate: sampleRate,
      numChannels: 1,
    );

    _stream = await _audioRecorder.startStream(config);

    debugPrint("Mobile mic listening");

    // accumulate audio chunks
    _audioStreamSubscription = _stream!.listen(
          (chunk) {
            _audioBuffer.add(chunk);
        },
    );

    // process accumulated audio periodically
    _startProcessingTimer();

  }

  @override
  Future<void> stopListening() async {
    _processingTimer?.cancel();
    _processingTimer = null;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    await _audioRecorder.stop();

    _audioBuffer.clear();
    _state = MicrophoneState.ready;

    // await textToSpeech.speak("Off"); //TODO -- add off state?
  }

  @override
  Future<void> pause() async {
    _processingTimer?.cancel();
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _audioRecorder.pause();
  }

  @override
  Future<void> resume() async {
    if (_state != MicrophoneState.passiveListening) {
      return; // don't resume if weren't listening
    }

    await _audioRecorder.resume();

    // restart the stream subscription
    _audioStreamSubscription = _stream!.listen(
        (chunk) {
          _audioBuffer.add(chunk);
        },
        onError: (error) {
          debugPrint("Audio stream error: $error");
        }
    );

    // restart the processing timer
    _processingTimer?.cancel(); // cancel any existing timer first
    _startProcessingTimer();
  }

  @override
  Future<void> dispose() async {
    await stopListening();
    await _audioRecorder.dispose();
    super.dispose();
  }

  void _startProcessingTimer() {
    _processingTimer?.cancel(); // ensure no duplicate timers

    _processingTimer = Timer.periodic(
      Duration(milliseconds: _bufferDurationMs),
          (_) async {
        if (_audioBuffer.isNotEmpty) {
          debugPrint("Processing ${_audioBuffer.length} chunks of audio");

          // flatten all chunks into single buffer
          final totalBytes = _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
          final combinedBuffer = Uint8List(totalBytes);
          var offset = 0;
          for (var chunk in _audioBuffer) {
            combinedBuffer.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }

          _audioBuffer.clear();

          String? result = processRecording(combinedBuffer);

          if (result != null && result.isNotEmpty) {
            debugPrint("Transcription: $result");
            await _onListeningResult!(result);
          }
        }
      },
    );
  }

}