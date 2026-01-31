import 'package:flutter/material.dart';
import '../../core/services/camera/camera_source.dart';
import '../../core/services/camera/mobile_camera_source.dart';
import '../../core/services/camera/hardware_camera_source.dart';
import '../../core/services/audio/microphone/microphone_source.dart';
import 'audio/microphone/hardware_microphone_source.dart';
import 'audio/microphone/mobile_microphone_source.dart';
import 'audio/speaker/speaker.dart';

/// A MediaManager handles all media interfaces: cameras, microphones, and speaker.
class MediaManager {

  // for camera
  late CameraSourceType _cameraSourceType;
  CameraSource? _cameraSource;

  // for microphone
  late MicrophoneSourceType _microphoneSourceType;
  MicrophoneSource? _microphoneSource;

  // for speaker
  late Speaker _speaker;

  // hardcoded hardware URL's
  final String _hardwareCameraUrl = "http://192.168.4.1:80/stream";
  final String _hardwareAudioUrl = "http://192.168.4.1:80/audio";

  CameraSourceType get cameraSourceType => _cameraSourceType;
  CameraSource? get cameraSource => _cameraSource;

  MicrophoneSourceType get microphoneSourceType => _microphoneSourceType;
  MicrophoneSource? get microphoneSource => _microphoneSource;
  Future<void> Function(String result)? _onListeningResult;

  MediaManager({required cameraSourceType, required microphoneSourceType, speakerConfig}) {

    _cameraSourceType = cameraSourceType;
    _microphoneSourceType = microphoneSourceType;

    // default parameters: language: "en-US", volume: 1.0, rate: 0.5
    _speaker = Speaker(
        language: (speakerConfig != null ? speakerConfig.language : "en-US"),
        volume: (speakerConfig != null ? speakerConfig.volume : 1.0),
        rate: (speakerConfig != null ? speakerConfig.rate : 0.5),
    );
  }

  /// Speak aloud the given text.
  ///
  /// Parameters:
  ///   text: the text to speak
  Future<void> speak(String text) async {
    // don't speak if mic is currently listening/user is currently recording
    if (_microphoneSource!.state == MicrophoneState.activeListening) {
      return;
    }

    // // only necessary if recording implemented without button (wake-word detection, etc)
    // final micExists = (_microphoneSource != null);
    // if (micExists) {
    //   await _microphoneSource!.pause();
    //   // await Future.delayed(const Duration(milliseconds: 200));
    // }

    debugPrint("Speaking: $text");
    await _speaker.speak(text);

    // // only necessary if recording implemented without button (wake-word detection, etc)
    // if (micExists) {
    //   // await Future.delayed(const Duration(milliseconds: 800));
    //   await _microphoneSource!.resume(); // so don't record speaker audio
    // }
  }

  /// Initialize camera and microphone,
  /// and give confirmation of text detection task.
  ///
  /// Parameters:
  ///   onListeningResult: callback function to handle result of completed listening
  Future<void> initialize(onListeningResult) async {
    debugPrint("Initializing ${cameraSourceType.name} camera...");
    await _initializeCamera();

    debugPrint("Initializing ${microphoneSourceType.name} microphone...");
    await _initializeMicrophone();

    _onListeningResult = onListeningResult;
  }

  /// Initialize microphone.
  Future<void> _initializeMicrophone() async {
    try {

      // create appropriate microphone source
      if (microphoneSourceType == MicrophoneSourceType.mobile) {
        _microphoneSource = MobileMicrophoneSource();
      }
      else {
        _microphoneSource = HardwareMicrophoneSource(_hardwareAudioUrl);
      }
      await _microphoneSource!.initialize();

    } catch (e) {
      debugPrint("Microphone initialization error: $e");
    }
  }

  /// Start the microphone's active listening.
  Future<void> startMicrophone() async {
    await _speaker.stop();
    await speak("On");
    await _microphoneSource!.startListening();
  }

  /// Stop the microphone's active listening.
  Future<void> stopMicrophone() async {
    await _microphoneSource!.stopListening(_onListeningResult!);
  }

  /// Initialize camera.
  Future<void> _initializeCamera() async {
    try {
      // create mobile camera source
      if (cameraSourceType == CameraSourceType.mobile) {
        _cameraSource = MobileCameraSource(
          minFrameInterval: const Duration(milliseconds: 50), // 20 FPS max
        );
      }

      // create hardware camera source
      else if (cameraSourceType == CameraSourceType.hardware){
        _cameraSource = HardwareCameraSource(
          HardwareCameraConfig(
              hardwareCameraUrl: _hardwareCameraUrl,
              timeout: const Duration(seconds: 10),
              reconnectDelay: const Duration(seconds: 2),
              maxReconnectAttempts: 5
          ),
        );
      }

      await _cameraSource!.initialize();

      // start camera
      try {
        await _cameraSource!.start();
      } catch (e) {
        debugPrint("Camera start error: $e");
        return; // don't continue if camera failed to start
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  /// Dispose of all media.
  Future<void> dispose() async {
    await _speaker.stop();
    await _cameraSource?.dispose();
    await _microphoneSource?.dispose();
  }

}