import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'camera_source.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

class HardwareCameraSource implements CameraSource {
  final HardwareCameraConfig config;

  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
  final StreamController<Uint8List> _previewController = StreamController<Uint8List>.broadcast();

  CameraState _state = CameraState.uninitialized;
  bool _isRunning = false;
  bool _isProcessingFrame = false;
  http.Client? _client;
  int _reconnectAttempts = 0;

  // frame metadata
  int? _frameWidth;
  int? _frameHeight;

  File? _tempFile;

  int _frameCount = 0;
  DateTime? _startTime;

  HardwareCameraSource(this.config);

  @override CameraState get state => _state;

  @override CameraSourceType get type => CameraSourceType.hardware;

  @override Future<void> initialize() async {
    if (_state != CameraState.uninitialized) {
      throw StateError("Camera already initialized");
    }

    _state = CameraState.initializing;
    debugPrint("Initializing hardware camera for ${config.hardwareCameraUrl}");

    _state = CameraState.ready;
    debugPrint("Camera initialized (connection will be tested on start)");

  }

  @override
  Future<void> start() async {
    if (state != CameraState.ready) {
      throw StateError("Camera not ready. Current state: $_state");
    }

    if (_isRunning) return;

    _isRunning = true;
    _reconnectAttempts = 0;

    // detect if it's a snapshot endpoint or stream
    await _detectAndStartStream();
  }

  Future<void> _detectAndStartStream() async {
    try {
      debugPrint("Testing stream type for ${config.hardwareCameraUrl}");

      final testClient = http.Client();
      final request = http.Request("GET", Uri.parse(config.hardwareCameraUrl));
      final response = await testClient.send(request).timeout(const Duration(seconds: 2));

      final contentType = response.headers['content-type'] ?? "";
      debugPrint("Content-Type: $contentType");

      // cancel request immediately
      testClient.close();

      if (contentType.contains("multipart")) {
        debugPrint("Detected MJPEG stream, using streaming mode");
        _startMjpegStream();
      } else {
        debugPrint("Detected snapshot endpoint, using polling mode");
      _startJpegPolling();
      }
    } catch (e) {
      debugPrint("Stream detection failed: $e, defaulting to polling");
      _startJpegPolling();
    }
  }

  Future<void> _startJpegPolling() async {
    const pollInterval = Duration(milliseconds: 33); // 30 FPS
    debugPrint("Starting JPEG polling at ${1000 ~/ pollInterval.inMilliseconds} FPS");

    while (_isRunning && _reconnectAttempts < config.maxReconnectAttempts) {
      try {
        // skip if previous frame still processing
        if (_isProcessingFrame) {
          await Future.delayed(pollInterval);
          continue;
        }

        final startTime = DateTime.now();

        final response = await http.get(Uri.parse(config.hardwareCameraUrl)).timeout(
            config.timeout);

        if (response.statusCode == 200) {
          await _processJpegFrame(response.bodyBytes);
          _reconnectAttempts = 0;

          // maintain consistent frame rate
          final elapsed = DateTime.now().difference(startTime);
          final remaining = pollInterval - elapsed;
          if (remaining > Duration.zero && _isRunning) {
            await Future.delayed(remaining);
          }
        } else {
          throw Exception("HTTP ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("JPEG polling error: $e");
        _reconnectAttempts++;

        if (_isRunning && _reconnectAttempts < config.maxReconnectAttempts) {
          debugPrint("Retry ${_reconnectAttempts}/${config.maxReconnectAttempts} in ${config.reconnectDelay.inSeconds}s");
          await Future.delayed(config.reconnectDelay);
        }
      }
    }

    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      _state = CameraState.error;
      debugPrint("Max reconnection attempts reached");
    }
  }

  // TODO - does mjpeg stream exist?
  void _startMjpegStream() async {
    while (_isRunning && _reconnectAttempts < config.maxReconnectAttempts) {
      _client = http.Client();

      try {
        final request = http.Request("GET", Uri.parse(config.hardwareCameraUrl));
        final response = await _client!.send(request).timeout(config.timeout);

        if (response.statusCode != 200) {
          throw Exception("HTTP ${response.statusCode}");
        }

        await _processMjpegStream(response.stream);

      } catch (e) {
        debugPrint("MJPEG stream error: $e");
        _reconnectAttempts++;

        if (_isRunning && _reconnectAttempts < config.maxReconnectAttempts) {
          debugPrint("Reconnecting in ${config.reconnectDelay.inSeconds}s...");
          await Future.delayed(config.reconnectDelay);
        }
      } finally {
        _client?.close();
      }
    }

    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      _state = CameraState.error;
      debugPrint("Max reconnection attempts reached");
    }
  }

  Future<void> _processMjpegStream(Stream<List<int>> stream) async {
    List<int> buffer = [];
    String? boundaryMarker;
    int? contentLength;
    bool inHeader = true;
    const int maxHeaderSize = 2048;
    const int maxBufferSize= 10 * 1024 * 1024; // 10MB max

    await for (var chunk in stream) {
      if (!_isRunning) break;

      buffer.addAll(chunk);

      // limit buffer size to prevent memory issues
      if (buffer.length > maxBufferSize) {
        debugPrint("Buffer overflow, resetting");
        buffer.clear();
        boundaryMarker = null;
        continue;
      }

      while (buffer.isNotEmpty) {
        if (inHeader) {
          // only decode enough bytes for header parsing
          final headerString = _getHeaderString(buffer, maxHeaderSize);

          // find or use boundary marker
          if (boundaryMarker == null) {
            boundaryMarker = _detectBoundaryMarker(headerString);
            if (boundaryMarker == null) {
              break;
            }
          }

          final boundaryIndex = headerString.indexOf(boundaryMarker);
          if (boundaryIndex == -1) {
            // no boundary in current buffer segment
            if (buffer.length >= maxHeaderSize) {
              // searched enough; clear and retry
              debugPrint(
                  "No boundary found in ${buffer.length} bytes, clearing");
              buffer.clear();
            }
            break;
          }

          // skip past boundary
          final afterBoundary = boundaryIndex + boundaryMarker.length;

          // find header end
          final headerEndIndex = headerString.indexOf('\r\n\r\n', afterBoundary);
          if (headerEndIndex == -1) {
            if (buffer.length < maxHeaderSize) {
              break; // wait for more data
            } else {
              // malformed header, skip this boundary
              buffer = buffer.sublist(afterBoundary);
              continue;
            }
          }

          // parse Content-Length
          final contentLengthMatch = RegExp(r'Content-Length:\s*(\d+)', caseSensitive: false)
              .firstMatch(headerString.substring(boundaryIndex, headerEndIndex));

          if (contentLengthMatch != null) {
            contentLength = int.parse(contentLengthMatch.group(1)!);
            buffer = buffer.sublist(headerEndIndex + 4); // skip /r/n/r/n
            inHeader = false;
          } else {
            debugPrint("No Content-Length found, skipping frame");
            buffer = buffer.sublist(afterBoundary);
          }

        } else {
          // extract JPEG frames
          if (contentLength != null && buffer.length >= contentLength) {
            final imageData = Uint8List.fromList(
                buffer.sublist(0, contentLength));

            await _processJpegFrame(imageData);

            buffer = buffer.sublist(contentLength);
            contentLength = null;
            inHeader = true;

          } else {
            break;
          }
        }
      }
    }
  }

  String? _detectBoundaryMarker(String headerString) {
    final boundaryMatch = RegExp(r'--([^\r\n]+)').firstMatch(headerString);
    if (boundaryMatch != null) {
      final marker = '--${boundaryMatch.group(1)!}';
      debugPrint("Detected boundary: $marker");
      return marker;
    }

    // try common defaults
    const commonBoundaries = [
      '--myboundary',
      '--frame',
      '--boundary',
      '--jpgboundary',
      '--BoundaryString',
    ];

    for (final boundary in commonBoundaries) {
      if (headerString.contains(boundary)) {
        debugPrint("Using common boundary: $boundary");
        return boundary;
      }
    }

    return null;
  }

  String _getHeaderString(List<int> buffer, int maxLength) {
    final searchLength = buffer.length > maxLength ? maxLength : buffer.length;
    try {
      return String.fromCharCodes(buffer.sublist(0, searchLength));
    } catch (e) {
      return "";
    }
  }

  Future<void> _processJpegFrame(Uint8List jpegData) async {
    // debugPrint("Received frame at ${DateTime.now()}");

    if (_isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;
    // debugPrint("Processing frame at ${DateTime.now()}");

    try {

      // FPS measurement
      _frameCount++;
      _startTime ??= DateTime.now();

      if (_frameCount % 30 == 0) {
        final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
        final fps = (_frameCount * 1000) / elapsed;
        debugPrint("Exact FPS: ${fps.toStringAsFixed(2)} (${_frameCount} frames in ${elapsed}ms)");
      }

      // decode JPEG to get dimensions on first frame
      if (_frameWidth == null || _frameHeight == null) {
        final image = img.decodeJpg(jpegData);
        if (image != null) {
          _frameWidth = image.width;
          _frameHeight = image.height;
        }
      }

      // emit for preview (JPEG can be displayed directly)
      if (_previewController.hasListener) {
        _previewController.add(jpegData);
      }

      // emit for processing
      if (_frameController.hasListener && _frameWidth != null && _frameHeight != null) {
        final frame = CameraFrame(
            imageData: jpegData,
            width: _frameWidth!,
            height: _frameHeight!,
            timestamp: DateTime.now(),
            format: ImageFormatType.jpeg,
        );

        _frameController.add(frame);
      }

      _reconnectAttempts = 0; // reset on successful frame

    } catch (e) {
      debugPrint("Error processing JPEG frame: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  Future<InputImage> createInputImage(CameraFrame frame) async {
    // write to temp file since ML kit needs file path for JPEG; once per frame
    if (_tempFile == null) {
      final tempDir = await Directory.systemTemp.createTemp("mlkit_");
      _tempFile = File('${tempDir.path}/frame.jpg');
    }
    await _tempFile!.writeAsBytes(frame.imageData, flush: true);
    return InputImage.fromFile(_tempFile!);

    // decode JPEG to get raw bytes
    final image = img.decodeJpg(frame.imageData);
    if (image == null) {
      throw Exception("Failed to decode JPEG");
    }

    // decode in separate isolate to avoid UI blocking
    final bytes = await compute(_decodeJpegToBgra, frame.imageData);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: frame.width * 4, // 4 bytes per pixel (BGRA)
      )
    );
  }

  static Uint8List _decodeJpegToBgra(Uint8List jpegData) {
    final image = img.decodeJpg(jpegData);
    if (image == null) {
      throw Exception("Failed to decode JPEG");
    }
    return image.getBytes(order: img.ChannelOrder.bgra);
  }

  @override
  Stream<CameraFrame> get frameStream => _frameController.stream;

  @override
  Widget buildPreview(BuildContext context) {
    return StreamBuilder<Uint8List>(
      stream: _previewController.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Connecting to hardware camera..."),
            ],
          ),
        );
      }

        // debugPrint("New frame: ${DateTime.now()}");

        return Image.memory(
        snapshot.data!,
        gaplessPlayback: true,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text("Error displaying frame"));
        },
      );
    },
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
  Future<void> stop() async {
    _isRunning = false;
    _client?.close();
  }

  @override
  Future<void> dispose() async {
    _state = CameraState.disposed;

    await stop();
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
  }
}

class CameraException implements Exception {
  final String code;
  final String message;

  CameraException(this.code, this.message);

  @override
  String toString() => "CameraException($code): $message";
}