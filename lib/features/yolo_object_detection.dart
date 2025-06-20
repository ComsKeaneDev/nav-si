import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:flutter_tts/flutter_tts.dart';

class YoloObjectDetection extends StatefulWidget {
  const YoloObjectDetection({Key? key}) : super(key: key);

  @override
  _YoloObjectDetectionState createState() => _YoloObjectDetectionState();
}

// none for initialization only
enum Task { person, chair, backpack, none }

class _YoloObjectDetectionState extends State<YoloObjectDetection> {
  // Controller must live in the State
  late final YOLOViewController controller;

  String currentModel = 'yolo11n';
  YOLOTask currentTask = YOLOTask.detect;
  bool isLoading = false;

  bool speakBool = false;
  var currentObjectTask = Task.none;

  FlutterTts flutterTts = FlutterTts();

  Future<void> switchToTask(Task newTask) async {
    currentObjectTask = newTask;
    print('Switched to task: $newTask');
    awaitSpeech();
    await speak('Switched to: $newTask');
  }

  Future<void> speak(String text) async {
    await flutterTts.setVolume(1.0);
    await flutterTts.speak(text);
  }

  void awaitSpeech() {
    flutterTts.awaitSpeakCompletion(true);
  }

  /// Quadrant 1 = top left, quadrant 2 = top right,
  /// quadrant 3 = bottom left, quadrant 4 = bottom right
  int determineQuadrant(Offset center) {
    int position;
    if (center.dx <= 0.5 && center.dy <= 0.5) {
      position = 1;
    } else if (center.dx > 0.5 && center.dy <= 0.5) {
      position = 2;
    } else if (center.dx <= 0.5 && center.dy > 0.5) {
      position = 3;
    } else {
      position = 4;
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

          // Object switching UI
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => switchToTask(Task.person),
                  child: Text('Person'),
                ),
                ElevatedButton(
                  onPressed: () => switchToTask(Task.chair),
                  child: Text('Chair'),
                ),
                ElevatedButton(
                  onPressed: () => switchToTask(Task.backpack),
                  child: Text('Backpack'),
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
                  print('Detected: ${result.className}, Confidence: ${result.confidence}');
                  if ('Task.${result.className}' == currentObjectTask.toString()) {
                    awaitSpeech();
                    final position = determineQuadrant(result.normalizedBox.center);
                    await speak('Found: ${result.className} in quadrant $position');
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
