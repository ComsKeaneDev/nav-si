import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import 'detection.dart';

class TextDetection extends StatefulWidget {
  const TextDetection({super.key});

  @override
  State<TextDetection> createState() => _TextDetectionState();
}

class _TextDetectionState extends State<TextDetection> with Detection {

  // controller
  CameraController? _cameraController;
  Future<void>? initializeControllerFuture;

  late String? targetText;
  final model = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    initialize();
  }

  /// Initialize camera and give confirmation of text detection task.
  Future<void> initialize() async {
    await Permission.camera.request().isGranted;
    final cameras = await availableCameras();

    _cameraController = CameraController(cameras[0], ResolutionPreset.max);
    initializeControllerFuture = _cameraController!.initialize();

    setState(() {});
    await textToSpeech.speak("Task: text detection.");
  }

  /// Continuously analyze camera frame.
  Future<void> startAnalyzingCamera() async {

    while (getSetting(Setting.search)) {

      final pic = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFile(File(pic.path));
      final RecognizedText recognizedText = await model.processImage(
          inputImage);
      final blocks = recognizedText.blocks;

      for (final block in blocks) {

        if (targetText == "") {
          for (final line in block.lines) {
            for (final element in line.elements) {
              await textToSpeech.speak(element.text);
            }
          }
        }
        else if (block.text.toLowerCase() == targetText!) {
          var textPosition = (getSetting(Setting.position)) ? "near "
              "${calculatePosition(
              block.boundingBox.center.dx, block.boundingBox.center.dy, 2600,
              4000)}" : "";
          await textToSpeech.speak('Found: $targetText $textPosition');
        }
      }
    }
  }

  /// Process the user's speech by updating the current text to search for, and
  /// beginning to analyze the camera in real time.
  ///
  /// Parameters:
  ///   result - the voice recording result of the user's speech
  Future<void> processSpeech(SpeechRecognitionResult result) async {

    // wait until result is final because partialResults = false isn't recognized when onDevice = true
    if (result.finalResult) {
      if (result.recognizedWords.isEmpty) {
        await textToSpeech.speak("Could not update search.", noLongerListening: true);
      }

      else {
        final String currentRecording = result.recognizedWords.toLowerCase();

        // handle settings updates
        bool settingsUpdated = await handleSettingCommands(context, currentRecording, textConfirmationMessage);
        if (settingsUpdated) {
          return;
        }

        // handle search update
        if (currentRecording.contains("all text")) {
          await updateTargetText("");
        }
        else {
          await updateTargetText(currentRecording);
        }

        await updateSetting(Setting.search, true);
        await startAnalyzingCamera();
      }
    }
  }

  /// Update target text and give confirmation message.
  ///
  /// Parameters:
  ///   newText: new text to search for
  Future<void> updateTargetText(String newText) async {
    setState(() { targetText = newText; });
    await textConfirmationMessage();
  }

  /// Give confirmation message of current target text.
  Future<void> textConfirmationMessage() async {
    final String confirmationMessage = (targetText == "") ? 'Searching for all text' : 'Searching for: $targetText';
    await textToSpeech.speak(confirmationMessage, noLongerListening: true);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text Detection'), automaticallyImplyLeading: false),
      body: FutureBuilder(

        future: initializeControllerFuture,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {

          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [

                // Recording UI
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await recordButtonPress(processSpeech);
                        },
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(Size(300, 40)),
                          backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                  (Set<WidgetState> states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.grey;
                                } else {
                                  return Colors.white;
                                }
                              }
                          ),
                        ),
                        child: Text('Record'),
                      ),
                    ],
                  ),
                ),

                // Navigation UI
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await switchToTask(Task.object, context);
                        },
                        child: Text('Object Detection'),
                      ),
                    ],
                  ),
                ),

                // Camera
                Transform.translate(
                  offset: Offset(0.0, 62.0),
                  child: Transform.scale(
                      scale: 1.25,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 9/12,
                          child: CameraPreview(_cameraController!),
                        )
                      )
                    ),
                  ),
              ],
            );
          } else {
            return Container();
          }
        }
      ));
  }
}