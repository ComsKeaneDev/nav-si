import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:ultralytics_yolo/yolo_task.dart';

class YoloDemo extends StatefulWidget {
  const YoloDemo({Key? key}) : super(key: key);

  @override
  _YoloDemoState createState() => _YoloDemoState();
}

class _YoloDemoState extends State<YoloDemo> {
  // Controller must live in the State
  late final YOLOViewController controller;

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

          // YoloView with controller
          Expanded(
              child: YOLOView(
                controller: controller,  // Provide the controller
                task: YOLOTask.detect,
                modelPath: 'yolo11n',  // Just the model name - most reliable approach
                onResult: (results) {
                  for (var result in results) {
                    print('Detected: ${result.className}, Confidence: ${result.confidence}');
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
