import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'camera_source.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A MobileCameraSource utilizes the phone's camera.
class MobileCameraSource extends CameraSource {

  CameraController? _controller;

  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
  @override CameraState state = CameraState.uninitialized;
  bool _isStreaming = false;
  DateTime _lastFrameTime = DateTime.now();

  // configurable frame throttling
  final Duration minFrameInterval;
  final ResolutionPreset resolution;

  // camera preview dimensions
  @override double? previewWidth;
  @override double? previewHeight;

  MobileCameraSource({
    this.minFrameInterval = const Duration(milliseconds: 100), // max 10 FPS
    this.resolution = ResolutionPreset.high,
  });

  @override CameraSourceType get type => CameraSourceType.mobile;

  CameraController? get controller => _controller;

  @override
  Future<void> initialize() async {
    if (state != CameraState.uninitialized) {
      throw StateError("Mobile camera already initialized");
    }

    state = CameraState.initializing;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException("NO_CAMERA", "No mobile cameras available");
      }

      _controller = CameraController(
        cameras[0],
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      state = CameraState.ready;
    } catch (e) {
      state = CameraState.error;
      rethrow;
    }
  }

  @override
  Future<void> start() async {
    if (state != CameraState.ready) {
      throw StateError("Mobile camera not ready. Current state: $state");
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
          rawImage: image,
        );

        _frameController.add(frame);
      } catch (e) {
        debugPrint("Error processing mobile camera frame: $e");
      }
    });
  }

  @override
  Future<InputImage> createInputImage(CameraFrame frame) async {
    final pic = await controller!.takePicture();
    return InputImage.fromFile(File(pic.path));
  }

  @override
  Future<Uint8List> createJpegImage(CameraFrame frame) async {

    final CameraImage image = frame.rawImage!;

    final rgb = await compute(_convertYUV420ToImage, image);

    return Uint8List.fromList(
      img.encodeJpg(rgb, quality: 90)
    );
  }

  static img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;


    final img.Image rgbImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final int yRow = yRowStride * y;
      final int uvRow = uvRowStride * (y >> 1);

      for (int x = 0; x < width; x++) {
        final int uvIndex = uvRow + (x >> 1) * uvPixelStride;

        final int yp = yPlane.bytes[yRow + x];
        final int up = uPlane.bytes[uvIndex];
        final int vp = vPlane.bytes[uvIndex];

        // convert YUV to RGB
        int r = (yp + 1.403 * (vp - 128)).round();
        int g = (yp - 0.344 * (up - 128) - 0.714 * (vp - 128)).round();
        int b = (yp + 1.770 * (up - 128)).round();

        rgbImage.setPixelRgb(
          x,
          y,
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255),
        );

      }
    }

    return rgbImage;
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
      return const Center(
          child: Column(
            spacing: 20,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(),
              Text("Connecting to mobile camera..."),
            ],
          ),
      );
    }

    // set dimensions
    if (previewWidth == null || previewHeight == null) {
      // preview size dimensions flipped
      previewWidth = controller!.value.previewSize!.height;
      previewHeight = controller!.value.previewSize!.width;
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
    if (state == CameraState.ready) {
      start();
    }
  }

  @override
  Future<void> dispose() async {
    state = CameraState.disposed;
    _isStreaming = false;

    await stop();
    await _controller?.dispose();
    await _frameController.close();
  }

}