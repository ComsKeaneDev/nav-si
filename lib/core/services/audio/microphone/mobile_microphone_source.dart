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

    // clear buffer multiple times to ensure empty
    _buffer.clear();
    await Future.delayed(const Duration(milliseconds: 100));
    _buffer.clear();

    await speechToText.resetStream();
    await Future.delayed(const Duration(milliseconds: 100));

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
  Future<void> stopListening(Future<void> Function(String result) onListeningResult) async {

    if (state != MicrophoneState.activeListening) {
      debugPrint("Hardware mic not actively listening; can't stop.");
      return;
    }

    // add delay to ensure final audio is captured
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("Stopping mobile microphone listening...");
    state = MicrophoneState.ready;

    await _cleanup();

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

        String? result = await processRecording(combinedBuffer);

        if (result != null && result.isNotEmpty) {
          debugPrint("Transcription: $result");
          await onListeningResult(result);
        } else {
          debugPrint("Buffer empty -- no audio to process");
        }

        await Future.delayed(const Duration(milliseconds: 150));
        await speechToText.resetStream();
      }
    }
  }

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