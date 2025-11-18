import 'dart:convert';
import 'dart:developer' as console;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../main.dart';
import 'detection_mixin.dart';

class ObjectDetection extends StatefulWidget {
  const ObjectDetection({super.key});

  @override
  State<ObjectDetection> createState() => _ObjectDetectionState();
}

class _ObjectDetectionState extends State<ObjectDetection> with DetectionMixin {

  // controller
  late final YOLOViewController _yoloController;
  Future<void>? initializeControllerFuture;

  // camera preview
  late final YOLOView yoloView;
  bool isYoloViewVisible = false;

  // model
  String model = 'yolo11n';
  YOLOTask modelTask = YOLOTask.detect;

  // COCO classes
  static final List<String> objectList = ["person", "bicycle", "car", "motorcycle", "airplane", "bus",
    "train", "truck", "boat", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench",
    "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
    "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite",
    "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle", "wine glass",
    "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot",
    "hot dog", "pizza", "donut", "cake", "chair", "couch", "potted plant", "bed", "dining table", "toilet",
    "tv", "laptop", "mouse", "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
    "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"];

  List<String> targetObjects = [];

  // for processImageResults
  Map<String, List> spokenLog = {}; // {(objectName : position), [int consecutiveTimesDetected, bool foundInThisFrame]}
  double targetRepeatPauseLength = 100.0; // how long to wait before announcing same target object again

  // toggle on/off ability to send JSON data of detected objects over network
  bool sendData = false;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  /// Initialize camera and controller, set initial thresholds,
  /// and give confirmation of object detection task.
  Future<void> initialize() async {
    // initialize controller and set initial thresholds
    await Permission.camera.request().isGranted;
    _yoloController = YOLOViewController();
    initializeControllerFuture = _yoloController.setThresholds(
      confidenceThreshold: 0.5,
      iouThreshold: 0.45,
    );

    // initialize camera
    yoloView = YOLOView(
        controller: _yoloController,
        task: modelTask,
        modelPath: model,
        streamingConfig: YOLOStreamingConfig(
          includeOriginalImage: true, // frames for color detection
        ),
        onStreamingData: (results) async {
          if (getSetting(Setting.search) && !isListening) {
            await processImageResults(results);
          }
        },
    );

    console.log("MaxFPSData" + yoloView.streamingConfig!.maxFPS.toString());
    console.log("InferenceFrequencyData" + yoloView.streamingConfig!.inferenceFrequency.toString());

    // ensure camera preview appears
    setState(() {
      isYoloViewVisible = true;
    });

    // announce current task
    await textToSpeech.speak("Task: object detection.");

    // if sending data: automatically search for all objects
    if (sendData) {
      await updateTargetObjects([...objectList]);
      await updateSetting(Setting.search, true);
    }
  }

  /// Process speech to perform next step: either switch to new task,
  /// update preferences for color and positional information, or
  /// update target objects (if able: otherwise give error message).
  ///
  /// Parameters:
  ///   result: audio recording result of spoken message
  Future<void> onListeningResult(SpeechRecognitionResult result) async {

    // to wait until result is final because partialResults = false is not recognized when onDevice = true
    if (result.finalResult) {

      final String currentRecording = result.recognizedWords.toLowerCase();

      // handle settings updates
      bool settingsUpdated = await handleSettingCommands(context, currentRecording, objectConfirmationMessage);
      if (settingsUpdated) {
        return;
      }

      // handle search update

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
            if ((recordedWords[i] == "bear" && i > 0 &&
                recordedWords[i - 1] == "teddy")
                || (recordedWords[i] == "dog" && i > 0 &&
                    recordedWords[i - 1] == "hot")) {
              targetObjectList.remove(recordedWords[i]);
            }
          }
          // two-word objects
          else if ((i < recordedWords.length - 1)) {
            String twoPartWord = "${recordedWords[i]} ${recordedWords[i + 1]}";
            if (objectList.contains(twoPartWord)) {
              targetObjectList.add(twoPartWord);
            }
          }
        }
      }

      // set target objects
      if (targetObjectList.isNotEmpty) {
        await updateTargetObjects(targetObjectList);
        await updateSetting(Setting.search, true);
      } else {
        await textToSpeech.speak("Failed to update search.", noLongerListening: true);
      }
    }
  }

  /// Update target objects and give confirmation message.
  ///
  /// Parameters:
  ///   newObjects: new objects to search for
  Future<void> updateTargetObjects(List<String> newObjects) async {
    setState(() { targetObjects = newObjects; });
    await objectConfirmationMessage();
  }

  /// Give confirmation message of current target objects.
  Future<void> objectConfirmationMessage() async {
    // give confirmation message
    if (listEquals(targetObjects, objectList)) {
      await textToSpeech.speak('Searching for all objects', noLongerListening: true);
    }
    else {
      String spokenObjectList = targetObjects[0];
      if (targetObjects.length > 1) {
        for (String object in targetObjects.sublist(1, targetObjects.length)) {
          spokenObjectList += "; $object";
        }
      }
      await textToSpeech.speak('Searching for: $spokenObjectList', noLongerListening: true);
    }
  }

  /// Processes image results to provide message about detected objects in current frame.
  ///
  /// Parameters:
  ///   results: data of current frame and detected objects
  Future<void> processImageResults(Map<String, dynamic> results) async {

    // results.keys: fps, frameNumber, processingTimeMs, originalImage, detections, timestamp

    // initially set all logged objects to have not been found in this frame
    spokenLog.updateAll((key, value) => [value[0], false]);

    for (var result in results["detections"]) {
      // result map: {boundingBox: {top: , left: , bottom: , right: }, classIndex: , confidence: , className: ,
      // normalizedBox: {top: , left: , bottom: , right: }}

      // to send data
      if (sendData) {
        final response = await http.post(
          Uri.parse('http://10.128.5.1:9753'), // change IP address here
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(toJson(result)),
        );

        // on unsuccessful request
        if (response.statusCode != 200) {
          await textToSpeech.speak("Error: failed to send data.");
        }
      }

      bool foundInThisFrame = true;
      final String object = result["className"].toLowerCase();

      // categories for which no color description should be given
      final List<String> noColorDescription = ["person"];

      if (targetObjects.contains(object)) {

        // get object position if necessary
        var objectPosition = (getSetting(Setting.position))? "near ${calculatePosition(
            (result["normalizedBox"]["left"]! + ((result["normalizedBox"]["right"]! - result["normalizedBox"]["left"]!) / 2)),
            (result["normalizedBox"]["top"]! + ((result["normalizedBox"]["bottom"]! - result["normalizedBox"]["top"]!) / 2)),
            1, 1)}"
            : "";

        // get color description if necessary
        var objectColor = "";
        if (!noColorDescription.contains(object) && getSetting(Setting.color)) {
          objectColor = calculateColor(results["originalImage"], result["boundingBox"]);
        }

        // processing to determine whether to announce detection again
        final String objectKey = "$object : $objectPosition";
        if (spokenLog.containsKey(objectKey)) {
          if (spokenLog[objectKey]?[0] < targetRepeatPauseLength) { // increment timer and don't announce again
            spokenLog.update((objectKey) , (value) => [value[0] + 1, foundInThisFrame]);
          } else {
            spokenLog.update((objectKey) , (value) => [0, foundInThisFrame]); // reset timer and announce again
            await textToSpeech.speak('Found: $objectColor $object $objectPosition');
          }
        } else {
          spokenLog[objectKey] = [0, foundInThisFrame]; // announce for first time
          await textToSpeech.speak('Found: $objectColor $object $objectPosition');
        }
      }
    }

    // remove previously found target objects not in current frame to reset log
    for (String key in spokenLog.keys) {
      if (spokenLog[key]?[1] == false) {
        spokenLog.remove(key);
      }
    }
  }

  /// Create a JSON map for a detected object.
  ///
  /// Parameters:
  ///   result: the detected object result
  ///
  /// Returns: a JSON map of the detected object's class name
  ///          and bounding box coordinates
  ///          (top = y-coordinate of top edge, bottom = y-coordinate of bottom edge,
  ///          left = x-coordinate of left edge, right = x-coordinate of right edge)
  Map<String, dynamic> toJson(Map result) {
    return {
      'object': result["className"].toLowerCase(),
      'top': result["boundingBox"]["top"],
      'bottom': result["boundingBox"]["bottom"],
      'left': result["boundingBox"]["left"],
      'right': result["boundingBox"]["right"]
    };
  }

  @override
  dispose() {
    _yoloController.stop();
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
                        await recordButtonPress(onListeningResult, onListeningDone);
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
                        await switchToTask(Task.text, context);
                      },
                      child: Text('Text Detection'),
                    ),
                  ],
                ),
              ),

              // YoloView
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