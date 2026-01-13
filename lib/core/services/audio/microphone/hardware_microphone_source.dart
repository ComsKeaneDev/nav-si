import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../microphone/microphone_source.dart';

class HardwareMicrophoneSource extends MicrophoneSource {

  static const _sampleRate = 16000;
  final String hardwareAudioUrl;
  MicrophoneState _state = MicrophoneState.uninitialized;
  HardwareMicrophoneSource(this.hardwareAudioUrl);

  @override MicrophoneState get state => _state;
  @override MicrophoneSourceType get type => MicrophoneSourceType.hardware;

  http.Client? _client;

  Future<void> Function(String result)? _onListeningResult;

  bool _justResumed = false;
  int _chunksToSkipAfterResume = 5; // skip ~150ms of audio after resuming

  @override
  Future<void> initialize() async {
    if (state != MicrophoneState.uninitialized) {
      return;
    }

    await super.initialize();

    _state = MicrophoneState.ready;
  }

  @override
  Future<void> startListening(
      Future<void> Function(String result) onListeningResult) async {
    if (_state == MicrophoneState.uninitialized) {
      await initialize();
    }

    if (_state == MicrophoneState.passiveListening) {
      debugPrint("Hardware stream already listening, skipping start");
      return;
    }

    _state = MicrophoneState.passiveListening;
    _onListeningResult = onListeningResult;

    try {
      _client = http.Client();

      final request = http.Request('GET', Uri.parse(hardwareAudioUrl));

      // add headers to prevent buffering and keep connection alive
      request.headers['Connection'] = 'keep-alive';
      request.headers['Cache-Control'] = 'no-cache';
      request.persistentConnection = true;

      debugPrint("Connecting to hardware audio stream at URL $hardwareAudioUrl...");

      final response = await _client!.send(request).timeout(
        const Duration(seconds: 30), // longer timeout for initial connection
        onTimeout: () {
          debugPrint("EP32 audio endpoint not responding after 30s");
          throw Exception("Audio stream connection timeout after 30s");
        }
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to audio stream: ${response.statusCode}');
      }

      debugPrint("Successfully connected to hardware audio stream");

      // stream audio chunks as they arrive
      const int chunkSize = 32000;
      List<int> buffer = [];
      int chunksReceived = 0;

      await for (var chunk in response.stream) {
        // stop processing
        if (_state == MicrophoneState.ready) {
          debugPrint("Microphone stopped");
          break;
        }

        // pause processing: if blocked (paused), don't add incoming chunks to buffer
        if (_state == MicrophoneState.blocked) {
          debugPrint("Microphone blocked, skipping current audio chunk");
          continue;
        }

        // skip chunks immediately after resume to avoid speaker echo
        if (_justResumed) {
          if (_chunksToSkipAfterResume > 0) {
            _chunksToSkipAfterResume--;
            debugPrint("Skipping post-resume chunk ($_chunksToSkipAfterResume left), buffer sizeL ${buffer.length}");
            continue;
          } else {
            _justResumed = false;
            _chunksToSkipAfterResume = 5; // reset for next pause/resume
            debugPrint("Resume transition complete, processing audio normally");
          }
        }

        // if (chunksReceived == 1) {
        //   debugPrint("First audio chunk received; stream active");
        // }

        chunksReceived++;
        buffer.addAll(chunk);

        // process when we have enough data
        while (buffer.length >= chunkSize) {
          if (_state != MicrophoneState.passiveListening) {
            break;
          }

          final audioChunk = Uint8List.fromList(buffer.sublist(0, chunkSize));
          buffer.removeRange(0, chunkSize);

          if (chunksReceived % 100 == 0) { // log every 100th chunk
            debugPrint("Processing hardware audio chunk #$chunksReceived");
          }

          final result = processRecording(audioChunk);
          if (result != null && result.isNotEmpty) {
            debugPrint("Transcription: $result");
            await onListeningResult(result);
          }
        }

        // if state changed to blocked during processing (exited while loop), clear remaining buffer
        if (_state == MicrophoneState.blocked && buffer.isNotEmpty) {
          debugPrint("Clearing ${buffer.length} bytes from buffer after pause");
          buffer.clear();
        }
      }

      debugPrint("Stream ended");

    } catch (e) {
      debugPrint("Hardware microphone error: $e");
      _state = MicrophoneState.ready;
    } finally {
      _client?.close();
      _client = null;
    }
  }

  /// Stop listening to voice.
  @override
  Future<void> stopListening() async {
    _state = MicrophoneState.ready;
    _client?.close();
    _client = null;
    // await speak(textToSpeech, "Off");
  }

  @override
  Future<void> pause() async {
    if (_state != MicrophoneState.passiveListening) {
      return;
    }

    _state = MicrophoneState.blocked;
    debugPrint("Hardware mic paused (keeping connection alive)");
  }

  @override
  Future<void> resume() async {
    if (_state != MicrophoneState.blocked) {
      return; // only resume if paused
    }

    _justResumed = true;
    _state = MicrophoneState.passiveListening;
    debugPrint("Hardware mic resuming - will skip next $_chunksToSkipAfterResume chunks");
  }

}