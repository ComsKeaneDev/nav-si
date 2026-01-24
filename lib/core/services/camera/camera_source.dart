import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum CameraSourceType {mobile, hardware}
enum CameraState {uninitialized, initializing, ready, error, disposed }
enum ImageFormatType {jpeg, yuv420} // nv21, rgb

abstract class CameraSource {
  CameraState get state;
  CameraSourceType get type;

  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
  Future<InputImage> createInputImage(CameraFrame frame);

  Stream<CameraFrame> get frameStream;
  double? get previewWidth;
  double? get previewHeight;

  Widget buildPreview(BuildContext context);

  // lifecycle callbacks
  void onAppPaused();
  void onAppResumed();
}

class CameraFrame{
  final Uint8List imageData;
  final int width;
  final int height;
  final DateTime timestamp;
  final ImageFormatType format;

  CameraFrame({
    required this.imageData,
    required this.width,
    required this.height,
    required this.timestamp,
    required this.format,
  });
}

