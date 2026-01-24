import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  @override CameraState state = CameraState.uninitialized;
  bool _isRunning = false;
  bool _isProcessingFrame = false;
  http.Client? _client;
  int _reconnectAttempts = 0;

  // for frames
  File? _tempFile;
  bool _tempFileInUse = false;
  final String _boundaryMarker = "--frame";

  // for better performance
  final Queue<Uint8List> _frameQueue = Queue<Uint8List>();
  Timer? _frameProcessingTimer;
  static const int _maxQueueSize = 5;
  static const Duration _processingInterval = Duration(milliseconds: 500); // 2 FPS

  // // for calculating fps
  // int _frameCount = 0;
  // DateTime? _startTime;

  // camera dimensions
  @override double previewWidth = 640;
  @override double previewHeight = 480;

  HardwareCameraSource(this.config);

  @override CameraSourceType get type => CameraSourceType.hardware;

  @override Future<void> initialize() async {
    if (state != CameraState.uninitialized) {
      throw StateError("Camera already initialized");
    }

    state = CameraState.initializing;
    debugPrint("Initializing hardware camera for ${config.hardwareCameraUrl}");

    state = CameraState.ready;
    debugPrint("Camera initialized (connection will be tested on start)");

  }

  @override
  Future<void> start() async {
    if (state != CameraState.ready) {
      throw StateError("Camera not ready. Current state: $state");
    }

    if (_isRunning) return;

    _isRunning = true;
    _reconnectAttempts = 0;

    _startFrameProcessor();
    _startMjpegStream();
  }

  Future<void> _startMjpegStream() async {
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
      state = CameraState.error;
      debugPrint("Max reconnection attempts reached");
    }
  }

  Future<void> _processMjpegStream(Stream<List<int>> stream) async {
    List<int> buffer = [];
    int? contentLength;
    bool inHeader = true;
    const int maxHeaderSize = 4096;
    const int maxBufferSize= 10 * 1024 * 1024;

    await for (var chunk in stream) {
      if (!_isRunning) break;

      buffer.addAll(chunk);

      // limit buffer size to prevent memory issues
      if (buffer.length > maxBufferSize) {
        buffer.clear();
        inHeader = true;
        contentLength = null;
        continue;
      }

      while (buffer.isNotEmpty && _isRunning) {
        if (inHeader) {
          final headerString = _getHeaderString(buffer, maxHeaderSize);
          final boundaryIndex = headerString.indexOf(_boundaryMarker);

          if (boundaryIndex == -1) {
            // no boundary in current buffer segment
            if (buffer.length >= maxHeaderSize) {
              debugPrint("No boundary found in ${buffer.length} bytes, clearing");
              buffer.clear();
            }
            break;
          }

          // skip past boundary
          final afterBoundary = boundaryIndex + _boundaryMarker.length;
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

            // queue frame instead of processing immediately
            _queueFrame(imageData);

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

  void _queueFrame(Uint8List jpegData) {
    if (!_isRunning) return;

    if (_previewController.hasListener) {
      _previewController.add(jpegData);
    }

    if (_frameController.hasListener) {
      if (_frameQueue.length >= _maxQueueSize) {
        _frameQueue.removeFirst(); // drop oldest frame
      }
      _frameQueue.add(jpegData);
    }

  }

  void _startFrameProcessor() {
    _frameProcessingTimer?.cancel();
    _frameProcessingTimer = Timer.periodic(_processingInterval, (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      if (_frameQueue.isNotEmpty && !_isProcessingFrame) {
        final frame = _frameQueue.removeFirst();
        _processQueuedFrame(frame);
      }
    });
  }

  void _processQueuedFrame(Uint8List jpegData) {
    if (_isProcessingFrame) return;

    _isProcessingFrame = true;

    Future.microtask(() async {
      try {
        final frame = CameraFrame(
          imageData: jpegData,
          width: previewWidth.toInt(),
          height: previewHeight.toInt(),
          timestamp: DateTime.now(),
          format: ImageFormatType.jpeg,
        );

        _frameController.add(frame);
      } catch (e) {
        debugPrint("Error creating camera frame: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  String _getHeaderString(List<int> buffer, int maxLength) {
    final searchLength = buffer.length > maxLength ? maxLength : buffer.length;
    try {
      return String.fromCharCodes(buffer.sublist(0, searchLength));
    } catch (e) {
      return "";
    }
  }

  @override
  Future<InputImage> createInputImage(CameraFrame frame) async {
    // write to temp file since ML kit needs file path for JPEG; once per frame
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
          return const Center(child: Text("Error displaying frame"));
        },
      );

      return cameraPreview;

    },
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
  Future<void> stop() async {
    _isRunning = false;
    _frameProcessingTimer?.cancel();
    _frameQueue.clear();
    _client?.close();
  }

  @override
  Future<void> dispose() async {
    state = CameraState.disposed;

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