import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'camera_source.dart';

/// A HardwareCameraConfig provides the parameters needed to use a hardware camera.
class HardwareCameraConfig {

  final String hardwareCameraUrl;
  final Duration timeout;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;

  const HardwareCameraConfig({
    required this.hardwareCameraUrl,
    this.timeout = const Duration(seconds: 10),
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 3,
  });

}

/// A HardwareCameraSource utilizes an external, hardware camera accessed through a URL that sends an MJPEG video stream.
class HardwareCameraSource extends CameraSource {

  final HardwareCameraConfig config;

  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
  final StreamController<Uint8List> _previewController = StreamController<Uint8List>.broadcast();

  http.Client? _client;

  // for frames
  File? _tempFile;
  bool _tempFileInUse = false;
  final String _boundaryMarker = "--frame";

  // // for calculating fps
  // int _frameCount = 0;
  // DateTime? _startTime;

  // hardcoded hardware camera dimensions
  @override double previewWidth = 640;
  @override double previewHeight = 480;

  HardwareCameraSource(this.config);

  @override CameraSourceType get type => CameraSourceType.hardware;

  @override
  Future<void> initialize() async {
    await super.initialize();

    state = CameraState.ready;
    debugPrint("Hardware camera initialized");
  }

  @override
  Future<void> start() async {
    if (state == CameraState.running) return;

    super.start();
    _startMjpegStream();
  }

  /// Helper function for start to initialize the MJPEG stream.
  Future<void> _startMjpegStream() async {
    Duration backoff = const Duration(seconds: 1);
    const maxBackoff = 30000; // 30 sec

    while (state == CameraState.running) {
      _client = http.Client();

      try {
        final request = http.Request("GET", Uri.parse(config.hardwareCameraUrl));
        final response = await _client!.send(request).timeout(config.timeout);

        if (response.statusCode != 200) {
          throw Exception("HTTP ${response.statusCode}");
        }

        // reset backoff on successful connection
        backoff = const Duration(seconds: 1);
        await _processMjpegStream(response.stream);

      } catch (e) {
        debugPrint("MJPEG stream error: $e");

        if (state == CameraState.running) {
          debugPrint("Reconnecting in ${backoff.inSeconds}s...");
          await Future.delayed(backoff);

          // exponential backoff with cap
          backoff = Duration(milliseconds: (backoff.inMilliseconds * 1.5).toInt().clamp(
              1000, maxBackoff)
          );
        }
      } finally {
        _client?.close();

        if (state == CameraState.running) {
          state = CameraState.error;
        }
      }
    }
  }

  /// Process the MJPEG stream of images, with buffer management.
  ///
  /// Parameters:
  ///   stream: the MJPEG stream to process
  Future<void> _processMjpegStream(Stream<List<int>> stream) async {
    List<int> buffer = [];
    const int maxBufferSize = 5 * 1024 * 1024;

    await for (var chunk in stream) {
      if (state != CameraState.running) break;

      buffer.addAll(chunk);

      // limit buffer size to prevent memory issues
      if (buffer.length > maxBufferSize) {
        buffer.clear();
        continue;
      }

      while (state == CameraState.running) {
        final bufferString = String.fromCharCodes(
            buffer, 0, buffer.length.clamp(0, 8192));
        final boundaryIndex = bufferString.indexOf(_boundaryMarker);

        if (boundaryIndex == -1) break; // need more data

        // find end of headers (\r\n\r\n)
        final headerEnd = bufferString.indexOf('\r\n\r\n', boundaryIndex);
        if (headerEnd == -1) break; // need more data

        // extract Content-Length
        final headerSection = bufferString.substring(boundaryIndex, headerEnd);
        final lengthMatch = RegExp(
            r'Content-Length:\s*(\d+)', caseSensitive: false)
            .firstMatch(headerSection);

        if (lengthMatch == null) {
          // skip to next potential boundary
          buffer = buffer.sublist(boundaryIndex + _boundaryMarker.length);
          continue;
        }

        final contentLength = int.parse(lengthMatch.group(1)!);
        final imageStart = headerEnd + 4; // skip /r/n/r/n

        // wait for complete image
        if (buffer.length < imageStart + contentLength) break;

        // extract and send frame
        final imageData = Uint8List.fromList(
            buffer.sublist(imageStart, imageStart + contentLength)
        );
        _sendJpeg(imageData);

        // remove processed frame from buffer
        buffer = buffer.sublist(imageStart + contentLength);
      }
    }
  }

  /// Send image to preview controller for mobile preview and to frame controller for output stream.
  ///
  /// Parameters:
  ///   jpegData: the image data to send
  void _sendJpeg(Uint8List jpegData) {
    if (state != CameraState.running) return;

    if (_previewController.hasListener) {
      _previewController.add(jpegData);
    }

    if (_frameController.hasListener) {
      final frame = CameraFrame(
        imageData: jpegData,
        width: previewWidth.toInt(),
        height: previewHeight.toInt(),
        timestamp: DateTime.now(),
        format: ImageFormatType.jpeg,
      );

      _frameController.add(frame);
    }

  }

  @override
  Future<InputImage> createInputImage(CameraFrame frame) async {
    // write to temp file once per frame
    while (_tempFileInUse) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _tempFileInUse = true;

    try {
      if (_tempFile == null) {
        final tempDir = await Directory.systemTemp.createTemp("mlkit_");
        _tempFile = File('${tempDir.path}/frame.jpg');
      }
      await _tempFile!.writeAsBytes(frame.imageData, flush: true);
      return InputImage.fromFile(_tempFile!);
    } finally {
      _tempFileInUse = false;
    }
  }

  @override
  Future<Uint8List> createJpegImage(CameraFrame frame) async {
    return frame.imageData;
  }

  @override
  Stream<CameraFrame> get frameStream => _frameController.stream;

  @override
  Future<void> stop() async {
    if (state != CameraState.running) return;

    await super.stop();
    _client?.close();
    _client = null;
  }

  @override
  Future<void> dispose() async {
    if (state == CameraState.disposed) return;

    _client?.close();
    _client = null;

    await _frameController.close();
    await _previewController.close();

    // clean up temp file
    if (_tempFile != null) {
      try {
        await _tempFile!.parent.delete(recursive: true);
      } catch (e) {
        debugPrint("Error cleaning up temp file: $e");
      }
    }

    await super.dispose();
  }

  @override
  Widget buildPreview(BuildContext context) {
    return StreamBuilder<Uint8List>(
      stream: _previewController.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(),
                Text("Connecting to hardware camera..."),
              ],
            ),
          );
        }

        // camera preview
        Image cameraPreview = Image.memory(
          snapshot.data!,
          gaplessPlayback: true,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Text("Error displaying hardware camera frame"));
          },
        );

        return cameraPreview;

      },
    );
  }

}