import 'dart:async';
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'speech_to_text_utils.dart';

class SpeechToText {

  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  final int _sampleRate = 16000;

  SpeechToText();

  Future<void> initialize() async {
    sherpa_onnx.initBindings();
    _recognizer = await _createOnlineRecognizer();
    if (_recognizer == null) {
      throw Exception("Failed to initialize recognizer");
    }

    _stream = _recognizer?.createStream();
    if (_stream == null) {
      throw Exception("Failed to initialize stream");
    }
  }

  Future<sherpa_onnx.OnlineRecognizer> _createOnlineRecognizer() async {

    final modelConfig = await getOnlineModelConfig();
    final config = sherpa_onnx.OnlineRecognizerConfig(
        model: modelConfig,
        ruleFsts: '',
        enableEndpoint: true
    );

    return sherpa_onnx.OnlineRecognizer(config);
  }

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

  String processRecording(Uint8List data) {

    // if (microphoneSource!.state == MicrophoneState.blocked) {
    //   _recognizer!.reset(_stream!);
    // }

    _recognizer!.reset(_stream!);

    // convert bytes to Float32
    final samplesFloat32 = convertBytesToFloat32(data);

    // pass to the model
    _stream!.acceptWaveform(samples: samplesFloat32, sampleRate: _sampleRate);

    // decode while there's data to decode
    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }

    // get the recognized text
    final result = _recognizer!.getResult(_stream!);
    final text = result.text.trim().toLowerCase();

    // if (_recognizer!.isEndpoint(_stream!) && text.isNotEmpty) {
    //   _recognizer!.reset(_stream!);
    // }

    // if (microphoneSource!.state == MicrophoneState.activeListening) {
    //   microphoneSource!.state = MicrophoneState.passiveListening;
    //   return text;
    // }

    // if (text.toLowerCase() == "hello") {
    //   microphoneSource!.state = MicrophoneState.activeListening;
    //   _recognizer!.reset(_stream!);
    // }

    // create new stream if endpoint detected
    // if (_recognizer!.isEndpoint(_stream!) && text.isNotEmpty) {
    //   _recognizer!.reset(_stream!);
    // }

    return text;

  }

  void dispose() {
    _stream?.free();
    _recognizer?.free();
  }


}
