import 'dart:async';
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:flutter/material.dart';
import 'speech_to_text_utils.dart';

/// SpeechToText enum for the current state of the transcription model's stream.
enum StreamState {
  uninitialized,
  ready,
  processing,
  finished,
  resetting,
  disposed
}

/// SpeechToText provides speech-to-text capabilities utilizing a transcription model.
class SpeechToText {

  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  final int _sampleRate = 16000;
  StreamState _streamState = StreamState.uninitialized;

  SpeechToText();

  /// Initialize the transcription model.
  Future<void> initialize() async {
    if (_streamState != StreamState.uninitialized) {
      return;
    }

    sherpa_onnx.initBindings();
    _recognizer = await _createOnlineRecognizer();
    if (_recognizer == null) {
      throw Exception("Failed to initialize recognizer");
    }

    _stream = _recognizer?.createStream();
    if (_stream == null) {
      throw Exception("Failed to initialize stream");
    }

    _streamState = StreamState.ready;
  }

  /// Helper function for initialize to create the streaming transcription model.
  ///
  /// Returns: the model
  Future<sherpa_onnx.OnlineRecognizer> _createOnlineRecognizer() async {

    final modelConfig = await getOnlineModelConfig();
    final config = sherpa_onnx.OnlineRecognizerConfig(
        model: modelConfig,
        ruleFsts: '',
        enableEndpoint: true
    );

    return sherpa_onnx.OnlineRecognizer(config);
  }

  /// Helper function for _createOnlineRecognizer to obtain the configuration
  /// for the streaming transcription model.
  ///
  /// Returns: the model's configuration
  Future<sherpa_onnx.OnlineModelConfig> getOnlineModelConfig() async {
    final modelDir = "assets/sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06";

    return sherpa_onnx.OnlineModelConfig(
      transducer: sherpa_onnx.OnlineTransducerModelConfig(
        encoder: await copyAssetFile('$modelDir/encoder.onnx'),
        decoder: await copyAssetFile('$modelDir/decoder.onnx'),
        joiner: await copyAssetFile('$modelDir/joiner.onnx'),
      ),
      tokens: await copyAssetFile('$modelDir/tokens.txt'),
      modelType: 'zipformer2',
      numThreads: 2, // optimize for mobile
    );
  }

  /// Transcribe audio recording data into text using the model.
  ///
  /// Parameters:
  ///   data: the audio recording data to transcribe
  ///
  /// Returns: the transcribed string of the audio data
  Future<String> processRecording(Uint8List data) async {
      if (_streamState != StreamState.ready || _stream == null || _recognizer == null) {
        return "";
      }

      _streamState = StreamState.processing;

      try {
        final samplesFloat32 = convertBytesToFloat32(data);

        // pass to the model
        _stream!.acceptWaveform(samples: samplesFloat32, sampleRate: _sampleRate);

        // decode
        while (_recognizer!.isReady(_stream!)) {
          _recognizer!.decode(_stream!);
        }

        // force final decoding to get complete result
        _stream!.inputFinished();

        while (_recognizer!.isReady(_stream!)) {
          _recognizer!.decode(_stream!);
        }

        // get the recognized text
        final result = _recognizer!.getResult(_stream!);
        final text = result.text.trim().toLowerCase();
        return text;

      } catch (e) {
        debugPrint("Error processing recording: $e");
        return "";
      } finally {
        _streamState = StreamState.ready;
        await Future.delayed(const Duration(milliseconds: 100));
      }
  }

  /// Resets the stream for a new processing session.
  Future<void> resetStream() async {
    if (_streamState == StreamState.disposed || _streamState == StreamState.resetting) {
      return;
    }

    _streamState = StreamState.resetting;

    try {
      // delay to ensure processing is complete
      await Future.delayed(const Duration(milliseconds: 200));

      if (_recognizer != null) {
        if (_stream != null) {
          _stream!.free();
          _stream = null;
        }

      _stream = _recognizer!.createStream();
      if (_stream == null) {
        throw Exception("Failed to create new stream after reset");
      }
    }

      _streamState = StreamState.ready;

    } catch (e) {
      debugPrint("Error resetting stream: $e");
      _streamState = StreamState.ready;
    }
  }

  /// Dispose of the model and stream.
  void dispose() {
    _streamState = StreamState.disposed;

    // delay actual disposal to ensure all operations are complete
    Future.delayed(const Duration(milliseconds: 300), () {
      _stream?.free();
      _recognizer?.free();
    });
  }

}
