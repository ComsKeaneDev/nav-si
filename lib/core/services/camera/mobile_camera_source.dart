import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'camera_source.dart';

/// A MobileCameraSource utilizes the phone's camera.
class MobileCameraSource extends CameraSource {

  CameraController? _controller;

  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
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
    super.initialize();

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
      debugPrint("Mobile camera initialized");
    } catch (e) {
      state = CameraState.error;
      rethrow;
    }
  }

  @override
  Future<void> start() async {
    if (state == CameraState.running) return;

    await super.start();

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

    final rgb = await compute(_convertYUV420ToRgb, image);

    return Uint8List.fromList(
      img.encodeJpg(rgb, quality: 90)
    );
  }

  /// Convert image from YUV420 format to RGB format.
  ///
  /// Parameters:
  ///   image: the image in YUV420 format
  ///
  /// Returns: the image in RGB format
  static img.Image _convertYUV420ToRgb(CameraImage image) {
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
  Stream<CameraFrame> get frameStream => _frameController.stream;

  @override
  Future<void> stop() async {
    if (state != CameraState.running) return;

    await super.stop();
    await _controller?.stopImageStream();
  }

  @override
  Future<void> dispose() async {
    if (state == CameraState.disposed) return;

    await _controller?.dispose();
    _controller = null;

    await _frameController.close();

    await super.dispose();
  }

  @override
  Widget buildPreview(BuildContext context) {
    if (state == CameraState.disposed) {
      return const SizedBox.shrink();
    }

    if (_controller == null || !(_controller!.value.isInitialized)) {
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

}