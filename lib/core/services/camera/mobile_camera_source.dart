import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'camera_source.dart';

class MobileCameraSource implements CameraSource {
  CameraController? _controller;

  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
  CameraState _state = CameraState.uninitialized;
  bool _isStreaming = false;
  DateTime _lastFrameTime = DateTime.now();

  // configurable frame throttling
  final Duration minFrameInterval;
  final ResolutionPreset resolution;

  MobileCameraSource({
    this.minFrameInterval = const Duration(milliseconds: 100), // max 10 FPS
    this.resolution = ResolutionPreset.high,
  });

  @override CameraState get state => _state;

  @override CameraSourceType get type => CameraSourceType.mobile;

  CameraController? get controller => _controller;

  @override Future<void> initialize() async {
    if (_state != CameraState.uninitialized) {
      throw StateError("Camera already initialized");
    }

    _state = CameraState.initializing;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException("NO_CAMERA", "No cameras available");
      }

      _controller = CameraController(
        cameras[0],
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _state = CameraState.ready;
    } catch (e) {
      _state = CameraState.error;
      rethrow;
    }
  }

  @override
  Future<void> start() async {
    if (state != CameraState.ready) {
      throw StateError("Camera not ready. Current state: $_state");
    }

    if (_isStreaming) return;
    _isStreaming = true;

    await _controller!.startImageStream((CameraImage image) {
      // throttle frames
      final now = DateTime.now();
      if (now.difference(_lastFrameTime) < minFrameInterval) {
        return;
      }
      _lastFrameTime = now;

      if (!_frameController.hasListener) return;

      try {
        final frame = CameraFrame(
          imageData: image.planes[0].bytes,
          width: image.width,
          height: image.height,
          timestamp: now,
          format: ImageFormatType.yuv420,
        );

        _frameController.add(frame);
      } catch (e) {
        debugPrint("Error processing camera frame: $e");
      }
    });
  }

  @override
  Future<InputImage> createInputImage(CameraFrame frame) async {
    final pic = await controller!.takePicture();
    return InputImage.fromFile(File(pic.path));
  }

    @override
  Future<void> stop() async {
    if (!_isStreaming) return;

    _isStreaming = false;
    await _controller?.stopImageStream();
  }

  @override
  Stream<CameraFrame> get frameStream => _frameController.stream;

  @override
  Widget buildPreview(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: CameraPreview(_controller!)
    );
  }

  @override
  void onAppPaused() {
    stop();
  }

  @override
  void onAppResumed() {
    if (_state == CameraState.ready) {
      start();
    }
  }

  @override
  Future<void> dispose() async {
    _state = CameraState.disposed;
    _isStreaming = false;

    await stop();
    await _controller?.dispose();
    await _frameController.close();
  }
}