import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../microphone/microphone_source.dart';

/// A HardwareMicrophoneSource utilizes an external, hardware mic accessed through a URL.
class HardwareMicrophoneSource extends MicrophoneSource {

  final String hardwareAudioUrl;

  HardwareMicrophoneSource(this.hardwareAudioUrl);

  @override MicrophoneSourceType get type => MicrophoneSourceType.hardware;

  http.Client? _client;
  StreamSubscription? _streamSubscription;
  final List<int> _buffer = [];

  @override
  Future<void> initialize() async {
    await super.initialize();

    // verify URL connection works
    try {
      // create test request
      _client = http.Client();
      final testRequest = http.Request('GET', Uri.parse(hardwareAudioUrl));
      // add headers to prevent buffering and keep connection alive
      testRequest.headers['Connection'] = 'keep-alive';
      testRequest.headers['Cache-Control'] = 'no-cache';

      debugPrint(
          "Testing connection to hardware audio stream at URL $hardwareAudioUrl...");

      // verify test response
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
    await super.startListening();

    if (state == MicrophoneState.activeListening) {
      return;
    }

    await _cleanup();

    _buffer.clear();
    await Future.delayed(const Duration(milliseconds: 100));
    _buffer.clear();

    // reset stream to prevent issues with audio data carrying over
    await speechToText.resetStream();
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint("Buffer cleared at start. Size: ${_buffer.length}");

    state = MicrophoneState.activeListening;

    // initiate URL connection
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

      // listen to response stream
      _streamSubscription = response.stream.listen(
        (chunk) {
          // accumulate audio chunks until active listening stops
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

  @override
  Future<void> stopListening(Future<void> Function(String result) onResult) async {
    if (state != MicrophoneState.activeListening) return;

    // add delay to ensure final audio is captured
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("Stopping hardware microphone listening...");
    state = MicrophoneState.ready;

    await _cleanup();
    await Future.delayed(const Duration(milliseconds: 500));

    // process buffer if not empty
    if (_buffer.isNotEmpty && state != MicrophoneState.disposed) {
      // copy and then clear original buffer to preserve audio data
      debugPrint("Processing buffer of size: ${_buffer.length}");
      final bufferCopy = Uint8List.fromList(_buffer);

      _buffer.clear();
      debugPrint("Buffer cleared. Current size: ${_buffer.length}");

      // transcribe audio data
      String? result = await transcribe(bufferCopy);

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

  /// Clean up the stream subscription and client.
  Future<void> _cleanup() async {
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
  Future<void> dispose() async {
    await _cleanup();
    _buffer.clear();
    await super.dispose();
  }

}