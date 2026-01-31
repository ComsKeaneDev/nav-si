import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Camera enums.
enum CameraSourceType {mobile, hardware}
enum CameraState {uninitialized, initializing, ready, running, error, disposed}
enum ImageFormatType {jpeg, yuv420} // other potential formats: nv21, rgb

/// A CameraSource provides video streaming capabilities.
abstract class CameraSource {

  CameraState state = CameraState.uninitialized;
  CameraSourceType get type;

  /// Initialize camera, ensuring successful connection.
  Future<void> initialize() async {
    if (state != CameraState.uninitialized) {
      throw StateError("Mobile camera already initialized");
    }
    state = CameraState.initializing;
  }

  /// Start the camera's video stream.
  Future<void> start() async {
    if (state != CameraState.ready) {
      throw StateError("Mobile camera not ready. Current state: $state");
    }
    state = CameraState.running;
  }

  /// Stop the camera's video stream.
  Future<void> stop() async {
    state = CameraState.ready;
  }

  /// Dispose of the camera, ending the connection.
  Future<void> dispose() async {
    state = CameraState.disposed;
  }

  /// Convert a camera frame to the input image format needed for the text detection model.
  ///
  /// Parameters:
  ///   frame: the camera frame to convert
  ///
  /// Returns: the converted input image format of the frame
  Future<InputImage> createInputImage(CameraFrame frame);

  /// Convert a camera frame to a JPEG format.
  ///
  /// Parameters:
  ///   frame: the camera frame to convert
  ///
  /// Returns: the JPEG image format of the frame
  Future<Uint8List> createJpegImage(CameraFrame frame);

  Stream<CameraFrame> get frameStream;
  double? get previewWidth;
  double? get previewHeight;

  Widget buildPreview(BuildContext context);

  /// Lifecycle callback when app is paused.
  void onAppPaused() {
    stop();
  }

  /// Lifecycle callback when app resumes.
  void onAppResumed() {
    if (state == CameraState.ready) {
      start();
    }
  }

}

/// A CameraFrame is one image in a camera's video stream.
class CameraFrame{
  final Uint8List imageData;
  final int width;
  final int height;
  final DateTime timestamp;
  final ImageFormatType format;
  final CameraImage? rawImage;

  CameraFrame({
    required this.imageData,
    required this.width,
    required this.height,
    required this.timestamp,
    required this.format,
    this.rawImage,
  });
}

