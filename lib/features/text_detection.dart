import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '/core/utils.dart';

class TextDetection extends StatefulWidget {
  const TextDetection({super.key});

  @override
  State<TextDetection> createState() => _TextDetectionState();
}

class _TextDetectionState extends State<TextDetection> {

  // controller
  CameraController? controller;
  Future<void>? initializeControllerFuture;

  // camera preview
  CameraPreview? cameraPreview;

  late String? targetText;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool searching = false; // default: searching off
  bool position = true; // default: positional information on

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeCamera();
    });
  }

  /// Initialize camera and give confirmation of switching task.
  Future<void> initializeCamera() async {
    await Permission.camera.request().isGranted;
    final cameras = await availableCameras();

    controller = CameraController(cameras[0], ResolutionPreset.max);
    initializeControllerFuture = controller!.initialize();

    setState(() {});
    await textToSpeech.speak("Task: text detection.");
  }

  /// Continuously analyze camera frame.
  Future<void> loopAnalyzeCamera() async {
    while (searching) {
      await analyzeCamera();
    }
  }

  /// Helper function for loopAnalyzeCamera. Determine if text was found
  /// in current frame, with confirmation message if so.
  Future<void> analyzeCamera() async {
    final pic = await controller!.takePicture();
    final inputImage = InputImage.fromFile(File(pic.path));
    final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage);
    final blocks = recognizedText.blocks;

    for (final block in blocks) {
      if (targetText == "") {
        await textToSpeech.speak(block.text);
      }
      else if (block.text.toLowerCase() == targetText!) {
        var textPosition = position? "near ${calculatePosition(block.boundingBox.center.dx, block.boundingBox.center.dy, 2600, 4000)}" : "";
        await textToSpeech.speak('Found: $targetText $textPosition');
      }
    }
  }

  /// Process the user's speech by updating the current text to search for and
  /// beginning to analyze the camera in real time.
  ///
  /// Parameters:
  ///   result - the voice recording result of the user's speech
  Future<void> processSpeech(SpeechRecognitionResult result) async {

    // to wait until result is final because partialResults = false
    // is not recognized when onDevice = true
    if (!result.finalResult) {
      return;
    }

    if (result.recognizedWords.isEmpty) {
      await textToSpeech.speak("Could not update search.");
    }

    else {
      final currentRecording = result.recognizedWords.toLowerCase();

      if (currentRecording == "switch to object detection") {
        await switchToTask("object");
        return;
      }

      // turning off search
      if (currentRecording == "search off") {
        searching = false;
        await textToSpeech.speak("Search turned off");
        return;
      }

      // reporting current search info
      if (currentRecording == "search settings") {
        await textToSpeech.speak("Search settings:");
        await textToSpeech.speak("Task: text detection");
        if (searching) {
          await textToSpeech.speak("Positional information: ${position? "on": "off"}");
          await textConfirmationMessage();
        }
        else {
          await textToSpeech.speak("Search: off");
        }
        return;
      }

      // updating positional information
      if (currentRecording == "position on") {
        position = true;
        await textToSpeech.speak("Positional information on");
        return;
      }
      else if (currentRecording == "position off") {
        position = false;
        await textToSpeech.speak("Positional information off");
        return;
      }

      if (currentRecording.contains("all text")) {
        await updateTargetText("");
      }

      else {
        await updateTargetText(currentRecording);
      }

      searching = true;
      await loopAnalyzeCamera();
    }
  }

  /// Update target text and give confirmation message.
  ///
  /// Parameters:
  ///   newText: new text to search for
  Future<void> updateTargetText(String newText) async {
    setState(() {
      targetText = newText;
    });

    await textConfirmationMessage();
  }

  /// Give confirmation message of current target text.
  Future<void> textConfirmationMessage() async {
    if (targetText == "") {
      await textToSpeech.speak('Searching for all text');
    }
    else {
      await textToSpeech.speak('Searching for: $targetText');
    }
  }

  /// Switch to new task.
  ///
  /// Parameters:
  ///   newTask: the task to switch to
  Future<void> switchToTask(String newTask) async {
    searching = false;
    context.push('/${newTask}_detection.dart');
  }

  @override
  void dispose() {
    controller?.dispose();
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
                          await speechToText.startListening(processSpeech);
                          await textToSpeech.speak("On");
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
                          searching = false;
                          context.push('/object_detection.dart');
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
                          child:CameraPreview(controller!),
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