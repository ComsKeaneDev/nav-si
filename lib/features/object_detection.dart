import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../core/services/camera_manager.dart';
import '../core/engine/nav_engine.dart';
import 'extensions/yolo_extension.dart';

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

  @override
  void initState() {
    super.initState();
    _setupArchitecture();
  }

  Future<void> _setupArchitecture() async {
    print("Step 1: Init Manager");
    _cameraManager = CameraManager();
    _engine = NavEngine(_cameraManager);

    print("Step 2: Init Engine (Camera)");
    await _engine.initialize();

    print("Step 3: Init Yolo Extension");
    _yoloExtension = YoloExtension();
    // _yoloExtension.sendData = true;

    _yoloExtension.outputStream.listen((message) {
      _handleExtensionOutput(message);
    });

    print("Step 4: Switch Mode (Load Model)");
    await _engine.switchMode([_yoloExtension]);

    print("Step 5: Done");
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

      print("UI Received: $message");
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Object Detection (Modular)')),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
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