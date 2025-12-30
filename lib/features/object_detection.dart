import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../core/services/camera_manager.dart';
import '../core/engine/nav_engine.dart';
import 'extensions/yolo_extension.dart';
import 'box_painter.dart';
import 'extensions/static_test_page.dart';

class ObjectDetection extends StatefulWidget {
  const ObjectDetection({super.key});

  @override
  State<ObjectDetection> createState() => _ObjectDetectionState();
}

class _ObjectDetectionState extends State<ObjectDetection> {
  late CameraManager _cameraManager;
  late NavEngine _engine;
  late YoloExtension _yoloExtension;

  bool _isInitialized = false;
  List<Map<String, dynamic>> _currentBoxes = [];

  @override
  void initState() {
    super.initState();
    _setupArchitecture();
  }

  Future<void> _setupArchitecture() async {
    _cameraManager = CameraManager();
    _engine = NavEngine(_cameraManager);

    await _engine.initialize();

    _yoloExtension = YoloExtension();
    // _yoloExtension.sendData = true;
    _yoloExtension.resultsStream.listen((boxes) {
      if (mounted) {
        setState(() {
          _currentBoxes = boxes;
        });
      }
    });

    _yoloExtension.outputStream.listen((message) {
      _handleExtensionOutput(message);
    });

    await _engine.switchMode([_yoloExtension]);

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      await textToSpeech.speak("Task: Object Detection initialized");
    }
  }

  void _handleExtensionOutput(dynamic message) {
    if (message is String) {
      textToSpeech.speak(message);

      // print("UI Received: $message");
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('Object Detection (Modular)')),
      body: !_isInitialized
        ? const Center(child: CircularProgressIndicator())
        : Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cameraManager.controller!),

            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      textToSpeech.speak("Recording not implemented in demo");
                    },
                    child: const Text('Record'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Back'),
                  ),

                  /// This part is a button for static image checking
                  ElevatedButton(
                    onPressed: () {
                      // textToSpeech.speak("Recording not implemented in demo");
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StaticTestPage()),
                      );
                    },
                    child: const Text('Debug Image'),
                  ),

                ],
              ),
            ),

            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: const Text(
                  "Mode: YOLO v1\nEngine: Running",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          ],
      ),
    );
  }
}