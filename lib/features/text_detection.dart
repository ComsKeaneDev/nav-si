import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/audio.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class TextDetection extends StatefulWidget {
  const TextDetection({super.key});

  @override
  State<TextDetection> createState() => _TextDetectionState();
}

class _TextDetectionState extends State<TextDetection> {
  CameraController? controller;
  Future<void>? initializeControllerFuture;
  CameraPreview? cameraPreview;
  bool searching = true;

  final FlutterTts textToSpeech = makeTextToSpeech();
  final SpeechToText speechToText = makeSpeechToText();

  late String? targetText;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

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
    await speak(textToSpeech, "Task: text detection.");
  }

  /// Continuously analyze camera frame every second.
  Future<void> loopAnalyzeCamera() async {
    while (searching) {
      await analyzeCamera();
      await(Future.delayed(const Duration(seconds: 1)));
    }
  }

  /// Determine if text was found in current frame and give confirmation message.
  Future<void> analyzeCamera() async {
    final pic = await controller!.takePicture();
    final inputImage = InputImage.fromFile(File(pic.path));
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    String text = recognizedText.text.toLowerCase();
    if (text.contains(targetText!)) {
      await speak(textToSpeech, 'Found: $targetText');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  /// Update the current text to search for and start analyzing camera.
  Future<void> processSpeech(SpeechRecognitionResult result) async {
    if (result.recognizedWords.isEmpty) {
      await speak(textToSpeech, "Could not update search.");
    }

    else {
      final currentRecording = result.recognizedWords.toLowerCase();

      if (currentRecording == "switch to object detection") {
        searching = false;
        context.push('/object_detection.dart');
      }

      else {
        targetText = currentRecording;

        await speak(textToSpeech, "Searching for text: $targetText");
        await loopAnalyzeCamera();
      }
    }
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
                        onPressed: () async => await startListening(textToSpeech, speechToText, processSpeech),
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