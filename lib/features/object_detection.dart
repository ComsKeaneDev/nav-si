import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';
import '/core/utils.dart';

class YoloObjectDetection extends StatefulWidget {
  const YoloObjectDetection({Key? key}) : super(key: key);

  @override
  _YoloObjectDetectionState createState() => _YoloObjectDetectionState();
}

class _YoloObjectDetectionState extends State<YoloObjectDetection> {

  // controller
  late final YOLOViewController controller;
  Future<void>? initializeControllerFuture;

  // camera preview
  late final YOLOView yoloView;
  bool isYoloViewVisible = false;

  // model
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

  List<String> targetObjects = [];

  bool searching = false; // default: searching off
  bool color = false; // default: color information off
  bool position = true; // default: positional information on

  // for processDetectedObjects "cache"
  Map<String, List> spokenLog = {}; // {(objectName : position), [int consecutiveTimesDetected, bool foundInThisFrame]}
  double targetRepeatPauseLength = 100.0; // how long to wait before announcing same target object again

  @override
  void initState() {
    super.initState();
    initialize();
  }

  /// Initialize camera and controller, set initial thresholds, and announce current task.
  Future<void> initialize() async {
    // initialize controller and set initial thresholds
    await Permission.camera.request().isGranted;
    controller = YOLOViewController();
    initializeControllerFuture = controller.setThresholds(
      confidenceThreshold: 0.5,
      iouThreshold: 0.45,
    );

    // initialize camera
    yoloView = YOLOView(
        controller: controller,
        task: currentTask,
        modelPath: currentModel,
        streamingConfig: YOLOStreamingConfig(
          includeOriginalImage: true, // frames for color detection
        ),
        onStreamingData: (results) async {
          await processImageResults(results);
        },
    );

    // ensure camera preview appears
    setState(() {
      isYoloViewVisible = true;
    });

    // announce current task
    await textToSpeech.speak("Task: object detection.");
  }

  /// Process speech to perform next step: either switch to new task,
  /// update preferences for color and positional information, or
  /// update target objects (if able: otherwise give error message).
  ///
  /// Parameters:
  ///   result: audio recording result of spoken message
  Future<void> processSpeech(SpeechRecognitionResult result) async {

    // to wait until result is final because partialResults = false is not recognized when onDevice = true
    if (!result.finalResult) {
      return;
    }

    final String currentRecording = result.recognizedWords.toLowerCase();

    // updating task
    if (currentRecording == "switch to text detection") {
      await switchToTask("text");
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
      await textToSpeech.speak("Task: object detection");
      if (searching) {
        await textToSpeech.speak("Positional information: ${position? "on": "off"}");
        await textToSpeech.speak("Color information: ${color? "on": "off"}");
        await objectConfirmationMessage();
      } else {
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

    // updating color information
    if (currentRecording == "color on") {
      color = true;
      await textToSpeech.speak("Color information on");
      return;
    }
    else if (currentRecording == "color off") {
      color = false;
      await textToSpeech.speak("Color information off");
      return;
    }

    // updating target objects
    List<String> targetObjectList = [];

    // all objects
    if (currentRecording.contains("all objects")) {
      targetObjectList = [...objectList];
    }

    // select objects
    else {
      List<String> recordedWords = currentRecording.split(" ");
      for (int i = 0; i < recordedWords.length; i += 1) {
        // one-word objects
        if (objectList.contains(recordedWords[i])) {
          targetObjectList.add(recordedWords[i]);
          // don't add duplicate of bear along with teddy bear or of dog along with hot dog
          if ((recordedWords[i] == "bear" && i > 0 && recordedWords[i - 1] == "teddy")
              || (recordedWords[i] == "dog" && i > 0 && recordedWords[i - 1] == "hot")) {
            targetObjectList.remove(recordedWords[i]);
          }
        }
        // two-word objects
        else if ((i < recordedWords.length - 1)) {
          String twoPartWord = "${recordedWords[i]} ${recordedWords[i+1]}";
          if (objectList.contains(twoPartWord)) {
            targetObjectList.add(twoPartWord);
          }
        }
      }
    }

    // set target objects
    if (targetObjectList.isNotEmpty) {
      await updateTargetObjects(targetObjectList);
      searching = true;
    } else {
      await textToSpeech.speak("Failed to update search.");
    }
  }

  /// Update target objects and give confirmation message.
  ///
  /// Parameters:
  ///   newObjects: new objects to search for
  Future<void> updateTargetObjects(List<String> newObjects) async {
    // update target objects
    setState(() {
      targetObjects = newObjects;
    });
    await objectConfirmationMessage();
  }

  /// Give confirmation message of current target objects.
  Future<void> objectConfirmationMessage() async {
    // give confirmation message
    if (listEquals(targetObjects, objectList)) {
      await textToSpeech.speak('Searching for: all objects');
    }
    else {
      String spokenObjectList = targetObjects[0];
      if (targetObjects.length > 1) {
        for (String object in targetObjects.sublist(1, targetObjects.length)) {
          spokenObjectList += "; $object";
        }
      }
      await textToSpeech.speak('Searching for: $spokenObjectList');
    }
  }

  /// Processes image results to provide message about detected objects in current frame.
  ///
  /// Parameters:
  ///   results: data of current frame and detected objects
  Future<void> processImageResults(Map<String, dynamic> results) async {

    // results.keys: fps, frameNumber, processingTimeMs, originalImage, detections, timestamp

    if (!searching) {
      return;
    }

    spokenLog.updateAll((key, value) => [value[0], false]);

    for (var result in results["detections"]) {
      // {boundingBox: {top: , left: , bottom: , right: }, classIndex: , confidence: , className: ,
      // normalizedBox: {top: , left: , bottom: , right: }}

      bool foundInThisFrame = true;
      final String object = result["className"].toLowerCase();

      // print('Detected: $object, Confidence: ${result["confidence"]}');

      final List<String> noColorDescription = ["person"];

      if (targetObjects.contains(object)) {
        var objectPosition = position? "near ${calculatePosition(
            (result["normalizedBox"]["left"]! + ((result["normalizedBox"]["right"]! - result["normalizedBox"]["left"]!) / 2)),
            (result["normalizedBox"]["top"]! + ((result["normalizedBox"]["bottom"]! - result["normalizedBox"]["top"]!) / 2)),
            1, 1)}"
            : "";

        var objectColor = "";
        if (!noColorDescription.contains(object) && color) {
          objectColor = calculateObjectColor(results["originalImage"], result["boundingBox"]);
        }

        final String objectKey = "$object : $objectPosition";
        if (spokenLog.containsKey(objectKey)) {
          if (spokenLog[objectKey]?[0] < targetRepeatPauseLength) { // don't announce again
            spokenLog.update((objectKey) , (value) => [value[0] + 1, foundInThisFrame]);
          } else {
            spokenLog.update((objectKey) , (value) => [0, foundInThisFrame]);
            await textToSpeech.speak('Found: $objectColor $object $objectPosition');
          }
        } else {
          spokenLog[objectKey] = [0, foundInThisFrame];
          await textToSpeech.speak('Found: $objectColor $object $objectPosition');
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

  /// Switch to new task.
  ///
  /// Parameters:
  ///   newTask: the task to switch to
  Future<void> switchToTask(String newTask) async {
    context.push('/${newTask}_detection.dart');
  }

  @override
  dispose() {
    controller.stop();
    super.dispose();
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
                      onPressed: () async {
                        await textToSpeech.speak("On");
                        await speechToText.startListening(processSpeech);
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