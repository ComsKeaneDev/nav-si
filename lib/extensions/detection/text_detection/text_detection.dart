import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/services/camera/camera_source.dart';
import '../../../core/services/audio/microphone/microphone_source.dart';
import '../../../core/services/media_manager.dart';
import '../../../core/orchestrator/extension_metadata.dart';
import '../detection_utils.dart';
import '../detection_settings.dart';
import '../../../ui/widgets/speak_button.dart';

class TextDetection extends StatefulWidget {
  const TextDetection({super.key});

  @override
  State<TextDetection> createState() => _TextDetectionState();
}

class _TextDetectionState extends State<TextDetection> {

  StreamSubscription<void>? _frameSubscription;

  String? targetText;
  bool _isProcessing = false;

  MediaManager? _mediaManager;

  DetectionSettings? _settings;

  final _model = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    initialize(onListeningResult);
  }

  Future<void> initialize(onListeningResult) async {
    _mediaManager = MediaManager(
      cameraSourceType: CameraSourceType.mobile,
      microphoneSourceType: MicrophoneSourceType.mobile,
    );

    await _mediaManager!.initialize(onListeningResult);

    if (mounted) { setState(() {}); }

    // update this: should be able to set default settings for detection
    _settings = DetectionSettings(ExtensionName.text, _mediaManager!, context);

    await _startProcessing();
    await _mediaManager!.speak("Task: text detection.");
  }

  Future<void> _startProcessing() async {
    await _frameSubscription?.cancel();

    _frameSubscription = _mediaManager!.cameraSource!.frameStream
        .where((_) => _settings!.searchOn) // && not actively listening?
        .where((_) => !_isProcessing) // skip frames if still processing
        .asyncMap((frame) async {
      _isProcessing = true;
      try {
        await _processCameraFrame(frame);
      } finally {
        _isProcessing = false;
      }
      })
      .listen(
        null,
        onError: (error) {
          debugPrint("Frame processing error: $error");
        },
      );
  }

  Future<void> _processCameraFrame(CameraFrame frame) async {

    try {
      final inputImage = await _mediaManager!.cameraSource!.createInputImage(frame);
      final recognizedText = await _model.processImage(inputImage);
      await _giveTextResults(recognizedText.blocks);

    } catch (e) {
      debugPrint("Text recognition error: $e");

    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _giveTextResults(List<TextBlock> blocks) async {
      for (final block in blocks) {
        debugPrint("Received text results");

        if (targetText == "") {
          await _mediaManager!.speak(block.text);
        }
        // for specific text
        else if (block.text.toLowerCase() == targetText!) {
          var textPosition = (_settings!.position) ? "near "
              "${calculatePosition(
                  centerCoordX: block.boundingBox.center.dx,
                  centerCoordY: block.boundingBox.center.dy,
                  frameWidth: 700,
                  frameHeight: 1300,
              )}" : ""; // TODO -- make numbers more robust - currently for frame with record button
          await _mediaManager!.speak('Found: $targetText $textPosition');
        }
      }
  }

  /// Process the user's speech by updating the current text to search for, and
  /// beginning to analyze the camera in real time.
  ///
  /// Parameters:
  ///   transcription - the transcribed result of the user's speech
  Future<void> onListeningResult(String transcription) async {

    // handle navigation
    if (transcription == "switch to object detection") {
      if (context.mounted) {
        context.push('/object_detection.dart');
      }
      return;
    }

    // handle settings updates
    final String message = (targetText == "") ? 'Searching for all text.' : 'Searching for: $targetText.';
    final settingsUpdated = await _settings!.handleSettingCommands(transcription, message);

    if (settingsUpdated) {
      await _startProcessing();
      return;
    }

    // handle search update
    if (transcription.contains("all text")) {
      await _updateTargetText("");
    }
    else {
      await _updateTargetText(transcription);
    }

    // start/continue searching
    await _settings!.updateSetting(DetectionSetting.searchOn, true);
    await _startProcessing();
  }

  // Future<void> onListeningDone() async {
  //   _mediaManager!.microphoneSource!.state = MicrophoneState.passiveListening;
  //   if (targetText != "") {
  //     await _startProcessing();
  //   }
  // }

  /// Update target text and give confirmation message.
  ///
  /// Parameters:
  ///   newText: new text to search for
  Future<void> _updateTargetText(String newText) async {
    setState(() {
      targetText = newText;
    });
    await  _mediaManager!.speak((targetText == "") ? 'Searching for all text' : 'Searching for: $targetText');
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _mediaManager!.dispose();
    _model.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
          title: const Text('Text Detection'),
          automaticallyImplyLeading: false,
          centerTitle: true,
      ),
      body: _mediaManager == null || _mediaManager!.cameraSource == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [

            const SizedBox(height: 10),

            // camera preview
            Expanded(
            child: _mediaManager!.cameraSource!.buildPreview(context),
            ),
          ],
        ),

      // navigation
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 10,
          children: [

            // navigation button
            // ElevatedButton(
            //   onPressed: () async {
            //     if (context.mounted) {
            //       context.push('/object_detection.dart');
            //     }
            //   },
            //   child: const Text('Object Detection'),
            // ),

            // record button
            SpeakButton(mediaManager: _mediaManager!),
          ],
        )
      ),
    );
  }
}