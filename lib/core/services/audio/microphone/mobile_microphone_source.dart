import 'dart:async';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'microphone_source.dart';

class MobileMicrophoneSource extends MicrophoneSource {
  late final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  final List<Uint8List> _buffer = [];
  Stream<Uint8List>? _stream;

  MobileMicrophoneSource();

  @override MicrophoneSourceType get type => MicrophoneSourceType.mobile;

  @override
  Future<void> initialize() async {

    if (state != MicrophoneState.uninitialized) {
      return;
    }

    await super.initialize();

    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      throw Exception("Microphone permission denied");
    }

    state = MicrophoneState.ready;

  }

  @override
  Future<void> startListening() async {
    if (state == MicrophoneState.uninitialized) {
      await initialize();
    }

    if (state == MicrophoneState.activeListening) {
      debugPrint("Mobile microphone started but already active listening");
      return;
    }

    await _cleanup();
    _buffer.clear();

    state = MicrophoneState.activeListening;

    const sampleRate = 16000;
    const encoder = AudioEncoder.pcm16bits;

    const config = RecordConfig(
      encoder: encoder,
      sampleRate: sampleRate,
      numChannels: 1,
    );

    try {
      _stream = await _audioRecorder.startStream(config);
      debugPrint("Mobile mic listening");

      // accumulate audio chunks
      _audioStreamSubscription = _stream!.listen(
            (chunk) {
          if (state == MicrophoneState.activeListening) {
            _buffer.add(chunk);
            debugPrint("Adding audio chunk to buffer.");
          }
        },
        onError: (error) {
          debugPrint("Audio stream error: $error");
          state = MicrophoneState.ready;
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
  Future<void> stopListening(Future<void> Function(String result) onListeningResult) async {

    if (state != MicrophoneState.activeListening) {
      debugPrint("Hardware mic not actively listening; can't stop.");
      return;
    }

    debugPrint("Stopping mobile microphone listening...");
    state = MicrophoneState.ready;

    await _cleanup();

    await Future.delayed(const Duration(milliseconds: 500));

    if (_buffer.isNotEmpty) {
      debugPrint("Processing buffer of size: ${_buffer.length}");

      // copy buffer & flatten all chunks into single buffer
      final bufferCopy = List<Uint8List>.from(_buffer);
      // clear original buffer
      _buffer.clear();
      debugPrint("Buffer cleared. Current size: ${_buffer.length}");

      final totalBytes = bufferCopy.fold<int>(0, (sum, chunk) => sum + chunk.length);
      if (totalBytes > 0) {
        final combinedBuffer = Uint8List(totalBytes);

        // copy data into combined buffer
        var offset = 0;
        for (var chunk in bufferCopy) {
          combinedBuffer.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }

        String? result = processRecording(combinedBuffer);

        if (result != null && result.isNotEmpty) {
          debugPrint("Transcription: $result");
          await onListeningResult(result);
        } else {
          debugPrint("Buffer empty -- no audio to process");
        }
      }
    }
  }

  Future<void> _cleanup() async {
    // cancel stream subscription
    if (_audioStreamSubscription != null) {
      await _audioStreamSubscription!.cancel();
      _audioStreamSubscription = null;
    }

    // stop audio recorder
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint("Error stopping mobile audio recorder: $e");
    }
  }

  @override
  Future<void> pause() async {
  }

  @override
  Future<void> resume() async {
  }

  @override
  Future<void> dispose() async {
    await _cleanup();
    _buffer.clear();
    await _audioRecorder.dispose();
    super.dispose();
  }

}