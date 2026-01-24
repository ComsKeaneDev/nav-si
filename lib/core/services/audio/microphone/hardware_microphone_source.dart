import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../microphone/microphone_source.dart';

class HardwareMicrophoneSource extends MicrophoneSource {

  final String hardwareAudioUrl;

  HardwareMicrophoneSource(this.hardwareAudioUrl);

  @override MicrophoneSourceType get type => MicrophoneSourceType.hardware;

  http.Client? _client;
  StreamSubscription? _streamSubscription;
  final List<int> _buffer = [];

  @override
  Future<void> initialize() async {
    if (state != MicrophoneState.uninitialized) {
      return;
    }

    await super.initialize();

    // verify connection works
    try {
      _client = http.Client();
      final testRequest = http.Request('GET', Uri.parse(hardwareAudioUrl));
      // add headers to prevent buffering and keep connection alive
      testRequest.headers['Connection'] = 'keep-alive';
      testRequest.headers['Cache-Control'] = 'no-cache';

      debugPrint(
          "Testing connection to hardware audio stream at URL $hardwareAudioUrl...");

      final testResponse = await _client!.send(testRequest).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception("Audio stream connection test timeout after 10s");
          }
      );

      if (testResponse.statusCode != 200) {
        throw Exception(
            'Failed to connect to audio stream: ${testResponse.statusCode}');
      }

      // close test connection
      testResponse.stream.listen(null).cancel();
      _client!.close();

      debugPrint("Hardware audio connection test successful");
      state = MicrophoneState.ready;
    } catch (e) {
      debugPrint("Hardware microphone error: $e");
      state = MicrophoneState.ready;
    }
  }

  @override
  Future<void> startListening() async {
    if (state == MicrophoneState.uninitialized) {
      await initialize();
    }

    if (state == MicrophoneState.activeListening) {
      debugPrint("Hardware stream already listening");
      return;
    }

    await _cleanup();

    _buffer.clear();
    await Future.delayed(const Duration(milliseconds: 100));
    _buffer.clear();

    await speechToText.resetStream();
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint("Buffer cleared at start. Size: ${_buffer.length}");

    state = MicrophoneState.activeListening;

    _client = http.Client();
    final request = http.Request('GET', Uri.parse(hardwareAudioUrl));
    // add headers to prevent buffering and keep connection alive
    request.headers['Connection'] = 'keep-alive';
    request.headers['Cache-Control'] = 'no-cache';

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to connect to audio stream: ${response.statusCode}');
      }

      debugPrint("Hardware audio connection successful.");
      debugPrint("Recording starting...");

      // listen to stream
      _streamSubscription = response.stream.listen(
        (chunk) {
          if (state == MicrophoneState.activeListening) {
            _buffer.addAll(chunk);
            debugPrint("Adding audio chunk to buffer.");
          }
        },
        onError: (error) {
          debugPrint("Stream error: $error");
          state = MicrophoneState.ready;
          _cleanup();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("Failed to start listening: $e");
      state = MicrophoneState.ready;
      rethrow;
    }
  }


  /// Stop listening to voice.
  @override
  Future<void> stopListening(Future<void> Function(String result) onListeningResult) async {
    if (state != MicrophoneState.activeListening) {
      debugPrint("Hardware mic not actively listening; can't stop.");
      return;
    }

    // add delay to ensure final audio is captured
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("Stopping hardware microphone listening...");
    state = MicrophoneState.ready;

    await _cleanup();
    await Future.delayed(const Duration(milliseconds: 500));

    if (_buffer.isNotEmpty) {
      debugPrint("Processing buffer of size: ${_buffer.length}");
      final bufferCopy = Uint8List.fromList(_buffer);

      // clear original buffer
      _buffer.clear();
      debugPrint("Buffer cleared. Current size: ${_buffer.length}");

      String? result = await processRecording(bufferCopy);
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

  Future<void> _cleanup() async {
    // cancel stream subscription first
    if (_streamSubscription != null) {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_client != null) {
      _client?.close();
      _client = null;
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
    super.dispose();
  }

}