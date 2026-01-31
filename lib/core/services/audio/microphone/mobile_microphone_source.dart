import 'dart:async';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'microphone_source.dart';

/// A MobileMicrophoneSource utilizes the phone's mic.
class MobileMicrophoneSource extends MicrophoneSource {

  late final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  final List<Uint8List> _buffer = [];
  Stream<Uint8List>? _stream;

  MobileMicrophoneSource();

  @override MicrophoneSourceType get type => MicrophoneSourceType.mobile;

  @override
  Future<void> initialize() async {
    await super.initialize();

    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      throw Exception("Microphone permission denied");
    }

    state = MicrophoneState.ready;

  }

  @override
  Future<void> startListening() async {
    super.startListening();

    if (state == MicrophoneState.activeListening) {
      return;
    }

    await _cleanup();

    // clear buffer multiple times to ensure empty
    _buffer.clear();
    await Future.delayed(const Duration(milliseconds: 100));
    _buffer.clear();

    // reset stream to prevent issues with audio data carrying over
    await speechToText.resetStream();
    await Future.delayed(const Duration(milliseconds: 100));

    state = MicrophoneState.activeListening;

    // create audio recorder config
    const sampleRate = 16000;
    const encoder = AudioEncoder.pcm16bits;
    const config = RecordConfig(
      encoder: encoder,
      sampleRate: sampleRate,
      numChannels: 1,
    );

    try {
      // start stream
      _stream = await _audioRecorder.startStream(config);
      debugPrint("Mobile mic listening");

      // accumulate audio chunks until active listening stops
      _audioStreamSubscription = _stream!.listen(
            (chunk) {
          if (state == MicrophoneState.activeListening && _audioStreamSubscription != null) {
            _buffer.add(chunk);
            debugPrint("Adding audio chunk to buffer.");
          }
        },
        onError: (error) {
          debugPrint("Audio stream error: $error");
          state = MicrophoneState.ready;
          _cleanup();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("Failed to start audio recording: $e");
      state = MicrophoneState.ready;
      rethrow;
    }
  }

  @override
  Future<void> stopListening(Future<void> Function(String result) onResult) async {
    if (state != MicrophoneState.activeListening) return;

    // add delay to ensure final audio is captured
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("Stopping mobile microphone listening...");

    state = MicrophoneState.ready;

    await _cleanup();

    // process buffer if not empty
    if (_buffer.isNotEmpty && state != MicrophoneState.disposed) {
      debugPrint("Processing buffer of size: ${_buffer.length}");

      // copy buffer & flatten all chunks into single buffer
      final bufferCopy = List<Uint8List>.from(_buffer);
      // clear original buffer
      _buffer.clear();
      debugPrint("Buffer cleared. Current size: ${_buffer.length}");

      final totalBytes = bufferCopy.fold<int>(0, (sum, chunk) => sum + chunk.length);
      if (totalBytes > 0) {
        final combinedBuffer = Uint8List(totalBytes);

        // copy audio data into combined buffer
        var offset = 0;
        for (var chunk in bufferCopy) {
          combinedBuffer.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }

        // transcribe audio data
        String? result = await transcribe(combinedBuffer);

        // process transcribed result if exists
        if (result != null && result.isNotEmpty) {
          debugPrint("Transcription: $result");
          await onResult(result);
        } else {
          debugPrint("Buffer empty -- no audio to process");
        }

        await Future.delayed(const Duration(milliseconds: 150));
        await speechToText.resetStream();
      }
    }
  }

  /// Helper function to clean up the audio recorder and stream subscription.
  Future<void> _cleanup() async {
    // stop audio recorder
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (e) {
      debugPrint("Error stopping mobile audio recorder: $e");
    }

    // cancel stream subscription
    if (_audioStreamSubscription != null) {
      await _audioStreamSubscription!.cancel();
      _audioStreamSubscription = null;
    }
  }

  @override
  Future<void> dispose() async {
    await _cleanup();
    _buffer.clear();
    await _audioRecorder.dispose();
    await super.dispose();
  }

}