import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../core/audio.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class YoloObjectDetection extends StatefulWidget {
  const YoloObjectDetection({Key? key}) : super(key: key);

  @override
  _YoloObjectDetectionState createState() => _YoloObjectDetectionState();
}

class _YoloObjectDetectionState extends State<YoloObjectDetection> {

  late final YOLOViewController controller;
  Future<void>? initializeControllerFuture;

  late final YOLOView yoloView;
  bool isYoloViewVisible = false;

  String currentModel = 'yolo11n';
  YOLOTask currentTask = YOLOTask.detect;

  // COCO classes
  final List<String> objectList = ["person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
    "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog",
    "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag",
    "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove",
    "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon",
    "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut",
    "cake", "chair", "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
    "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
    "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"];

  final FlutterTts textToSpeech = makeTextToSpeech();
  final SpeechToText speechToText = makeSpeechToText();

  List<String> targetObjects = [];
  String currentRecording = "";

  // for processDetectedObjects
  Map<String, List> spokenLog = {}; // {(objectName : position), [int consecutiveTimesDetected, bool foundInThisFrame]}
  double targetRepeatPauseLength = 100.0; // how long to wait before announcing same target object again

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  /// Initialize camera and give confirmation of switching task.
  Future<void> initializeCamera() async {
    // Initialize controller and set initial thresholds
    await Permission.camera.request().isGranted;
    controller = YOLOViewController();
    initializeControllerFuture = controller.setThresholds(
      confidenceThreshold: 0.5,
      iouThreshold: 0.45,
    );
    yoloView = YOLOView(
        controller: controller,
        task: currentTask,
        modelPath: currentModel,
        onResult: (results) async {
      await processDetectedObjects(results);
    });

    setState(() {
      isYoloViewVisible = true;
    });

    await speak(textToSpeech, "Task: object detection.");
  }

  @override
  dispose() {
    controller.stop();
    super.dispose();
  }

  /// Processes speech to update target objects if able, or otherwise give error message.
  ///
  /// Parameters:
  ///   result: audio recording result of spoken message
  void processSpeech(SpeechRecognitionResult result) async {
    currentRecording = result.recognizedWords.toLowerCase();

    if (currentRecording == "switch to text detection") {
      context.push('/text_detection.dart');
    }

    else {
      List<String> targetObjectList = [];
      List<String> recordedWords = currentRecording.split(" ");
      for (int i = 0; i < recordedWords.length; i += 1) {
        // one-word objects
        if (objectList.contains(recordedWords[i])) {
          targetObjectList.add(recordedWords[i]);
        }
        // two-word objects
        else if ((i < recordedWords.length - 1)) {
          String twoPartWord = "${recordedWords[i]} ${recordedWords[i+1]}";
          if (objectList.contains(twoPartWord)) {
            targetObjectList.add(twoPartWord);
          }
        }
      }
      if (targetObjectList.isNotEmpty) {
        await updateTargetObjects(targetObjectList);
      } else {
        await speak(textToSpeech, "Failed to update search.");
      }
    }
  }

  // Updates target object and gives confirmation message.
  Future<void> updateTargetObjects(List<String> newObjects) async {
    // update target objects
    setState(() {
      targetObjects = newObjects;
    });

    // give confirmation message
    String spokenObjectList = newObjects[0];
    if (newObjects.length > 1) {
      for (String object in newObjects.sublist(1, newObjects.length)) {
        spokenObjectList += "; $object";
      }
    }
    await speak(textToSpeech, 'Searching for: $spokenObjectList');
  }

  /// Returns a description of the object's position as being in 1 of 9 quadrants:
  /// upper left edge, upper edge, upper right edge, left edge, center, right edge,
  /// lower left edge, lower edge, lower right edge.
  ///
  /// Parameters:
  ///   center: the normalized coordinates in [0, 1.0] of the center of the object's
  ///           bounding box
  String calculateObjectPosition(Offset center) {
    final position;
    final firstThird = 1/3;
    final secondThird = 2/3;
    final x = center.dx;
    final y = center.dy;

    if (y <= firstThird) {
      if (x <= firstThird) {
        position = "upper left edge";
      }
      else if (x > secondThird) {
        position = "upper right edge";
      }
      else {
        position = "upper edge";
      }
    }
    else if (y > firstThird && y <= secondThird) {
      if (x <= firstThird) {
        position = "left edge";
      }
      else if (x > secondThird) {
        position = "right edge";
      }
      else {
        position = "center";
      }
    }
    else {
      if (x <= firstThird) {
        position = "lower left edge";
      }
      else if (x > secondThird) {
        position = "lower right edge";
      }
      else {
        position = "lower edge";
      }
    }
    return position;
  }

  /// Gives message about detected objects in current frame, taking into
  /// account if exact object in position has recently been announced.
  ///
  /// Parameters:
  ///   results: all detected objects in current frame
  Future<void> processDetectedObjects(List<YOLOResult> results) async {
    spokenLog.updateAll((key, value) => [value[0], false]);
    for (var result in results) {
      bool foundInThisFrame = true;
      final String object = result.className.toLowerCase();
      print('Detected: $object, Confidence: ${result.confidence}');
      if (targetObjects.contains(object)) {
        final String objectPosition = calculateObjectPosition(result.normalizedBox.center);
        final String objectKey = "$object : $objectPosition";
        if (spokenLog.containsKey(objectKey)) {
          if (spokenLog[objectKey]?[0] < targetRepeatPauseLength) { // don't announce again
            spokenLog.update((objectKey) , (value) => [value[0] + 1, foundInThisFrame]);
          } else {
            spokenLog.update((objectKey) , (value) => [0, foundInThisFrame]);
            await speak(textToSpeech, 'Found: $object near $objectPosition');
          }
        } else {
          spokenLog[objectKey] = [0, foundInThisFrame];
          await speak(textToSpeech, 'Found: $object near $objectPosition');
        }
      }
    }
    // remove previously found target objects not in current frame to reset
    for (String key in spokenLog.keys) {
      if (spokenLog[key]?[1] == false) {
        spokenLog.remove(key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        appBar: AppBar(title: const Text('Object Detection'), automaticallyImplyLeading: false),
        body: initializeControllerFuture == null ? Container() : FutureBuilder(

        future: initializeControllerFuture,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {

          if (snapshot.connectionState == ConnectionState.done) {
          return Column(
            children: [
              // Controls for adjusting detection parameters
              // Padding(
              //   padding: const EdgeInsets.all(10.0),
              //   child: Row(
              //     children: [
              //       const Text('Confidence: '),
              //       Expanded(
              //         child: Slider(
              //           value: controller.confidenceThreshold,
              //           min: 0.1,
              //           max: 0.9,
              //           onChanged: (value) {
              //             setState(() {
              //               controller.setConfidenceThreshold(value);
              //             });
              //           },
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

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
                bottom: 50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        context.push('/text_detection.dart');
                      },
                      child: Text('Text Detection'),
                    ),
                  ],
                ),
              ),

              // YoloView with controller
              Expanded(
                child: isYoloViewVisible? yoloView : Container(),
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