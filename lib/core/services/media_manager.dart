import 'package:flutter/material.dart';
import '../../core/services/camera/camera_source.dart';
import '../../core/services/camera/mobile_camera_source.dart';
import '../../core/services/camera/hardware_camera_source.dart';
import '../../core/services/audio/microphone/microphone_source.dart';
import '../../core/services/audio/microphone/mobile_microphone_source.dart';
import '../../core/services/audio/speaker.dart';
import 'audio/microphone/hardware_microphone_source.dart';

/// Wrapper class around all media
class MediaManager {
  late CameraSourceType _cameraSourceType;
  late MicrophoneSourceType _microphoneSourceType;
  MicrophoneSource? _microphoneSource;
  CameraSource? _cameraSource;
  late Speaker _speaker;

  CameraSourceType get cameraSourceType => _cameraSourceType;
  MicrophoneSourceType get microphoneSourceType => _microphoneSourceType;
  // TODO - should these getters exist?
  CameraSource? get cameraSource => _cameraSource;
  MicrophoneSource? get microphoneSource => _microphoneSource;

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

  /// Speak aloud the given text with microphone coordination (pausing/resuming).
  ///
  /// Parameters:
  ///   text: text to speak
  Future<void> speak(String text) async {
    final micExists = (_microphoneSource != null);
    if (micExists) {
      await _microphoneSource!.pause();      // so don't record speaker audio
      // await Future.delayed(const Duration(milliseconds: 200));
    }

    debugPrint("Speaking: $text");
    await _speaker.speak(text);

    if (micExists) {
      // await Future.delayed(const Duration(milliseconds: 800));
      await _microphoneSource!.resume(); // so don't record speaker audio
    }
  }


  // media manager should have a method that closes everything; should have own switch to task method that stops speech;
  // have each page itself speak the current task so the detections.utils page doesn't have to worry about it
  // and then replace all the closing functions in text detection with the media manager

// TODO - figure out if camera is mjpeg streaming or jpeg polling

  /// Initialize camera and microphone,
  /// and give confirmation of text detection task.
  Future<void> initialize({required onListeningResult}) async {
    await _initializeCamera();
    debugPrint("$cameraSourceType camera initialized");

    await _initializeMicrophone(onListeningResult);
    debugPrint("$microphoneSourceType microphone initialized");
  }

  /// Start microphone.
  Future<void> _initializeMicrophone(onListeningResult) async {
    try {

      // create appropriate microphone source
      if (microphoneSourceType == MicrophoneSourceType.mobile) {
        _microphoneSource = MobileMicrophoneSource();
      }
      else {
        String hardwareAudioUrl = "http://192.168.4.1:80/audio";
        _microphoneSource = HardwareMicrophoneSource(hardwareAudioUrl);
      }
      await _microphoneSource!.initialize();
      var listeningFuture = _microphoneSource!.startListening(onListeningResult);

      listeningFuture.catchError((error) {
        debugPrint("Listening error: $error");
        // try to reconnect after error
        if (microphoneSourceType == MicrophoneSourceType.hardware) {
          debugPrint("Attempting to reconnect to hardware microphone...");
          Future.delayed(const Duration(seconds: 2), () {
            listeningFuture = _microphoneSource!.startListening(onListeningResult);
          });
        }
      });

      // await speaker.speak("Mic on");

    } catch (e) {
      debugPrint("Microphone initialization error: $e");
    }
  }

  /// Initialize camera.
  Future<void> _initializeCamera() async {
    try {
      // create appropriate camera source
      if (cameraSourceType == CameraSourceType.mobile) {
        _cameraSource = MobileCameraSource(
          minFrameInterval: const Duration(milliseconds: 50), // 20 FPS max
        );
      }

      else if (cameraSourceType == CameraSourceType.hardware){
        String hardwareCameraUrl = "http://192.168.4.1:80/stream";
        _cameraSource = HardwareCameraSource(
          HardwareCameraConfig(
              hardwareCameraUrl: hardwareCameraUrl,
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

  Future<void> dispose() async {
    _speaker.stop();
    _cameraSource?.dispose();
    _microphoneSource?.stopListening(); // close HTTP client
    _microphoneSource?.dispose();
}

}



