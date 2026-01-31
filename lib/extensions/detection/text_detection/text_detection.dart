import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/services/media_manager.dart';
import '../../../core/services/camera/camera_source.dart';
import '../../../core/services/audio/microphone/microphone_source.dart';
import 'text_detection_settings.dart';
import '../detection_settings.dart';
import '../detection_utils.dart';
import '../../../ui/widgets/speak_button.dart';

// Extension metadata:
//  name: Text Detection
//  version: 1.0.0
//  author: Kailey Epstein
//  description: Search for surrounding text, with the ability to detect all text, or a specified target (with optional position information).
//  permissions: camera (for mobile), microphone (for mobile)
//  camera sources: mobile, hardware
//  microphone sources: mobile, hardware

class TextDetection extends StatefulWidget {
  const TextDetection({super.key});

  @override
  State<TextDetection> createState() => _TextDetectionState();
}

class _TextDetectionState extends State<TextDetection> {

  // for media manager
  MediaManager? _mediaManager;
  // choose camera & microphone source types (mobile vs. hardware)
  final _cameraSourceType = CameraSourceType.mobile;
  final _microphoneSourceType = MicrophoneSourceType.mobile;

  TextDetectionSettings? _settings;

  // text detection model
  final _model = TextRecognizer(script: TextRecognitionScript.latin);

  StreamSubscription<void>? _frameSubscription;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Async helper function for initState to initialize the media manager and settings.
  Future<void> _initialize() async {
    // initialize media manager
    _mediaManager = MediaManager(
      cameraSourceType: _cameraSourceType,
      microphoneSourceType: _microphoneSourceType,
    );

    try {

      await _mediaManager!.initialize(_onListeningResult);

      if (mounted) { setState(() {}); }

      // initialize settings
      _settings = TextDetectionSettings(_mediaManager!);

      await _mediaManager!.speak("Text detection extension.");
      await _startProcessing();

    } catch (e) {
      debugPrint("Initialization error: $e");
    }

  }

  /// Start text detection processing of camera frames.
  Future<void> _startProcessing() async {
    // return if already processing
    if (_frameSubscription != null) {
      return;
    }

    // create subscription to camera frames
    _frameSubscription = _mediaManager!.cameraSource!.frameStream
        .where((_) => _settings!.search!) // currently searching
        .listen((frame) async {
          if (_isProcessing) return; // drop frames if processing
          _isProcessing = true;

          try {
            await _processCameraFrame(frame);
          } finally {
            _isProcessing = false;
          }
        },
          onError: (error) {
            debugPrint("Frame processing error: $error");
          },
        );
  }

  /// Process a single camera frame to detect text.
  ///
  /// Parameters:
  ///   frame: the camera frame to process
  Future<void> _processCameraFrame(CameraFrame frame) async {

    try {
      final inputImage = await _mediaManager!.cameraSource!.createInputImage(frame);
      final recognizedText = await _model.processImage(inputImage);
      await _reportTextResults(recognizedText.blocks);

    } catch (e) {
      debugPrint("Text recognition error: $e");
    }
  }

  /// Report the results of the text detection based on the target text.
  ///
  /// Parameters:
  ///   blocks: the text blocks to analyze to report if target text is found
  Future<void> _reportTextResults(List<TextBlock> blocks) async {
      for (final block in blocks) {
        String targetText = _settings!.target;

        // for all text
        if (targetText == "") {
          await _mediaManager!.speak(block.text);
        }
        // for specific text
        else if (block.text.toLowerCase() == targetText) {
          var textPosition = "";
          if (_settings!.position!) {
            textPosition = "near ${calculatePosition(
                  centerX: block.boundingBox.center.dx,
                  centerY: block.boundingBox.center.dy,
                  frameWidth: _mediaManager!.cameraSource!.previewWidth!,
                  frameHeight: _mediaManager!.cameraSource!.previewHeight!)}";
          }
          await _mediaManager!.speak('Found: $targetText $textPosition');
        }
      }
  }

  /// Process speech to perform correct next step: switching extensions, updating
  /// settings, or updating search targets.
  ///
  /// Parameters:
  ///   transcription - the transcribed result of the user's speech
  Future<void> _onListeningResult(String transcription) async {

    // handle navigation
    if (transcription == "switch to object detection") {
      await _cleanup();

      if (context.mounted) {
        context.go('/object_detection.dart');
      }
      return;
    }

    // handle settings commands; start processing and return if settings updated
    if (await _settings!.handleSettingCommands(transcription)) {
      return;
    }

    // handle search update
    if (transcription.contains("all text")) {
      await _updateTargetText("");
    }
    else {
      await _updateTargetText(transcription);
    }
    if (!(_settings!.search!)) {
      await _settings!.updateSettings(DetectionSetting.search, true);
    }
  }

  /// Update target text and give confirmation message.
  ///
  /// Parameters:
  ///   newText: new text to search for; "" = all text, otherwise the string is the specific target text
  Future<void> _updateTargetText(String newText) async {
    setState(() {
      _settings!.target = newText;
    });
    await _mediaManager!.speak((newText == "") ? 'Searching for all text' : 'Searching for: $newText');
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  /// Clean up the frame subscription, model, and media manager.
  Future<void> _cleanup() async {
    // cancel frame subscription
    await _frameSubscription?.cancel();
    _frameSubscription = null;

    // dispose model
    await _model.close();

    // dispose media manager
    if (_mediaManager != null) {
      await _mediaManager!.dispose();
      _mediaManager = null;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      // record button
      floatingActionButton: SpeakButton(mediaManager: _mediaManager!),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // header
      appBar: AppBar(
          title: const Text('Text Detection'),
          automaticallyImplyLeading: false,
          centerTitle: true,
      ),

      // camera preview
      body: _mediaManager == null || _mediaManager!.cameraSource == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [

            const SizedBox(height: 10),

            Expanded(
            child: _mediaManager!.cameraSource!.buildPreview(context),
            ),
          ],
        ),

      // navigation
      // bottomNavigationBar: BottomAppBar(
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.end,
      //     spacing: 10,
      //     children: [
      //
      //       // navigation button
      //       // ElevatedButton(
      //       //   onPressed: () async {
      //       //     if (context.mounted) {
      //       //       context.push('/object_detection.dart');
      //       //     }
      //       //   },
      //       //   child: const Text('Object Detection'),
      //       // ),
      //
      //     ],
      //   )
      // ),
    );
  }
}