import 'dart:math' hide log;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import 'package:image/image.dart' as image;

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

  // for calculateObjectColor
  final colorPalette = {
    "black": Color.fromARGB(255, 0, 0, 0),
    "white": Color.fromARGB(255, 255, 255, 255),
    "red": Color.fromARGB(255, 255, 0, 0),
    "green": Color.fromARGB(255, 0, 255, 0),
    "blue": Color.fromARGB(255, 0, 0, 255),
    "yellow": Color.fromARGB(255, 255, 255, 0),
    // "cyan": Color.fromARGB(255, 0, 255, 255),
    // "magenta": Color.fromARGB(255, 255, 0, 255),
  };
  bool color = false;

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
  /// update target objects if able, or otherwise give error message.
  ///
  /// Parameters:
  ///   result: audio recording result of spoken message
  Future<void> processSpeech(SpeechRecognitionResult result) async {

    // to wait until result is final because partialResults = false is not recognized when onDevice = true
    if (!result.finalResult) {
      return;
    }

    final String currentRecording = result.recognizedWords.toLowerCase();
    // await textToSpeech.speak("$currentRecording");

    // updating task
    if (currentRecording == "switch to text detection") {
      await switchToTask("text");
    }

    // updating color search
    else if (currentRecording == "color on") {
      color = true;
      await textToSpeech.speak("Color search on");
    }
    else if (currentRecording == "color off") {
      color = false;
      await textToSpeech.speak("Color search off");
    }

    // updating target objects
    else {
      // create target object list
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
      } else {
        await textToSpeech.speak("Failed to update search.");
      }
    }
  }

  /// Update target object and give confirmation message.
  ///
  /// Parameters:
  ///   newObjects: new objects to search for
  Future<void> updateTargetObjects(List<String> newObjects) async {
    // update target objects
    setState(() {
      targetObjects = newObjects;
    });

    // give confirmation message
    if (listEquals(newObjects, objectList)) {
      await textToSpeech.speak('Searching for: all objects');
    }
    else {
      String spokenObjectList = newObjects[0];
      if (newObjects.length > 1) {
        for (String object in newObjects.sublist(1, newObjects.length)) {
          spokenObjectList += "; $object";
        }
      }
      await textToSpeech.speak('Searching for: $spokenObjectList');
    }
  }


  /// Helper function for processDetectedObjects. Finds an object's closest color.
  ///
  /// Parameters:
  ///   boundingBox: the object's bounding box
  ///
  /// Returns: the closest color to the object's color
  String calculateObjectColor(Uint8List frame, Map boundingBox) {

    // to focus on center of object
    final cropFraction = 0.2;

    // bounding box information
    final width = (boundingBox["right"] - boundingBox["left"]).round();
    final height = (boundingBox["bottom"] - boundingBox["top"]).round();

    final startY = (boundingBox["top"] + (height * cropFraction)).round();
    final endY = (boundingBox["bottom"] - (height * cropFraction)).round();
    final startX = (boundingBox["left"] + (width * cropFraction)).round();
    final endX = (boundingBox["right"] - (width * cropFraction)).round();

    // decode image
    final decoder = image.JpegDecoder();
    final decodedImage = decoder.decode(frame) as image.Image;
    final decodedImageRgb = decodedImage.getBytes(order: image.ChannelOrder.rgb);

    // find pixel averages
    double redSum = 0;
    double greenSum = 0;
    double blueSum = 0;

    final frameWidth = decodedImage.width;
    for (int y = startY; y < endY; y += 1) {
      for (int x = startX; x < endX; x += 1) {
        redSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3)];
        greenSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3) + 1];
        blueSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3) + 2];
      }
    }

    final area = (width * (1  - 2 * cropFraction)) * (height * (1  - 2 * cropFraction));

    return calculateClosestColor(Color.fromARGB(255,
        (redSum / area).round(), (greenSum / area).round(), (blueSum / area).round()));
  }

  /// Helper function for calculateObjectColor.
  ///
  /// Parameters:
  ///   color: the average RGB color of the object's bounding box
  ///
  /// Returns: the name of the closest color to the object's color
  String calculateClosestColor(Color color) {
    
    var closestColor = "";
    num closestColorDistance = 195075; // 3 * 255^2

    for (var colorName in colorPalette.keys) {
      final otherColorRgb = colorPalette[colorName]!;
      final colorDistance = pow(otherColorRgb.r - color.r, 2) +
          pow(otherColorRgb.g - color.g, 2) +
          pow(otherColorRgb.b - color.b, 2);

      if (colorDistance < closestColorDistance) {
        closestColorDistance = colorDistance;
        closestColor = colorName;
      }
    }

    return closestColor;
  }

  /// Helper function for processDetectedObjects.
  ///
  /// Parameters:
  ///   normalizedPositions: the normalized fractional values in [0, 1.0] of the
  ///   top, bottom, left, and right edges of the object's bounding box
  ///
  /// Returns: a description of the location where the object is centered at
  ///   (1 of 9 quadrants: upper left edge, upper edge, upper right edge,
  ///   left edge, center, right edge, lower left edge, lower edge, lower right edge)
  String calculateObjectPosition(Map normalizedPositions) {
    final String position;

    final firstThird = 1/3;
    final secondThird = 2/3;

    // find centers
    final centerY = normalizedPositions["top"]!
        + ((normalizedPositions["bottom"]! - normalizedPositions["top"]!) / 2);
    final centerX = normalizedPositions["left"]!
        + ((normalizedPositions["right"]! - normalizedPositions["left"]!) / 2);

    // top third
    if (centerY <= firstThird) {
      if (centerX <= firstThird) {
        position = "upper left edge";
      }
      else if (centerX > secondThird) {
        position = "upper right edge";
      }
      else {
        position = "upper edge";
      }
    }
    // middle third
    else if (centerY > firstThird && centerY <= secondThird) {
      if (centerX <= firstThird) {
        position = "left edge";
      }
      else if (centerX > secondThird) {
        position = "right edge";
      }
      else {
        position = "center";
      }
    }
    // bottom third
    else {
      if (centerX <= firstThird) {
        position = "lower left edge";
      }
      else if (centerX > secondThird) {
        position = "lower right edge";
      }
      else {
        position = "lower edge";
      }
    }
    return position;
  }

  /// Processes image results to provide message about detected objects in current frame.
  ///
  /// Parameters:
  ///   results: data of current frame and detected objects
  Future<void> processImageResults(Map<String, dynamic> results) async {

    // results.keys: fps, frameNumber, processingTimeMs, originalImage, detections, timestamp

    spokenLog.updateAll((key, value) => [value[0], false]);

    for (var result in results["detections"]) {
      // {boundingBox: {top: , left: , bottom: , right: }, classIndex: , confidence: , className: ,
      // normalizedBox: {top: , left: , bottom: , right: }}

      bool foundInThisFrame = true;
      final String object = result["className"].toLowerCase();

      // print('Detected: $object, Confidence: ${result["confidence"]}');

      final List<String> noColorDescription = ["person"];

      if (targetObjects.contains(object)) {
        final String objectPosition = calculateObjectPosition(result["normalizedBox"]);
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
            await textToSpeech.speak('Found: $objectColor $object near $objectPosition');
          }
        } else {
          spokenLog[objectKey] = [0, foundInThisFrame];
          await textToSpeech.speak('Found: $objectColor $object near $objectPosition');
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