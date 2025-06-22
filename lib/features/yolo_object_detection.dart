import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../core/audio.dart';

class YoloObjectDetection extends StatefulWidget {
  const YoloObjectDetection({Key? key}) : super(key: key);

  @override
  _YoloObjectDetectionState createState() => _YoloObjectDetectionState();
}

// TODO
// - changing confidence slider resets state = no longer searching for object

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

class _YoloObjectDetectionState extends State<YoloObjectDetection> {
  // Controller must live in the State
  late final YOLOViewController controller;

  String currentModel = 'yolo11n';
  YOLOTask currentTask = YOLOTask.detect;

  FlutterTts textToSpeech = makeTextToSpeech();
  SpeechToText speechToText = makeSpeechToText();

  var targetObjects = [];
  String currentRecording = "";

  // processes speech to update target object if able or otherwise gives error message
  void processSpeech(SpeechRecognitionResult result) async {
    currentRecording = result.recognizedWords;
    List<String> targetObjectList = [];
    for (final word in currentRecording.toLowerCase().split(" ")) {
      if (objectList.contains(word)) {
        targetObjectList.add(word);
      }
    }
    if (targetObjectList.isNotEmpty) {
      await updateTargetObjects(targetObjectList);
      return;
    }
    await speak(textToSpeech, "Failed to update search.");
  }

  // updates target object and gives affirmative message
  Future<void> updateTargetObjects(List<String> newObjects) async {
    targetObjects = newObjects;
    String spokenObjectList = "";
      spokenObjectList = newObjects[0];
    if (newObjects.length > 1) {
      for (String object in newObjects.sublist(1, newObjects.length)) {
        spokenObjectList += "; $object";
      }
    }
    await speak(textToSpeech, 'Searching for: $spokenObjectList');
  }

  // returns a description of the object's position: upper left, upper right,
  // lower left, or lower right
  String calculateObjectPosition(Offset center) {
    String position;
    if (center.dx <= 0.5 && center.dy <= 0.5) {
      position = "upper left";
    } else if (center.dx > 0.5 && center.dy <= 0.5) {
      position = "upper right";
    } else if (center.dx <= 0.5 && center.dy > 0.5) {
      position = "lower left";
    } else {
      position = "lower right";
    }
    return position;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOLO Object Detection')),
      body: Column(
        children: [
          // Controls for adjusting detection parameters
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('Confidence: '),
                Expanded(
                  child: Slider(
                    value: controller.confidenceThreshold,
                    min: 0.1,
                    max: 0.9,
                    onChanged: (value) {
                      setState(() {
                        controller.setConfidenceThreshold(value);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Recording UI
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

          // YoloView with controller
          Expanded(
            child: YOLOView(
              controller: controller,  // Provide the controller
              task: currentTask,
              modelPath: currentModel,
              onResult: (results) async {
                for (var result in results) {
                  final String object = result.className.toLowerCase();
                  print('Detected: $object, Confidence: ${result.confidence}');
                  if (targetObjects.contains(object)) {
                    final String objectPosition = calculateObjectPosition(result.normalizedBox.center);
                    await speak(textToSpeech, 'Found: $object in $objectPosition');
                  }
                }
              },
            )
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize controller and set initial thresholds
    controller = YOLOViewController();
    controller.setThresholds(
      confidenceThreshold: 0.5,
      iouThreshold: 0.45,
    );
  }
}