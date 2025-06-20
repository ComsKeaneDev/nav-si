import 'package:all_brawn/misc/websocket_test.dart';
import 'package:flutter/material.dart';
import 'ui/yolo_demo.dart';
import 'features/yolo_object_detection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: YoloObjectDetection(),
    );
  }
}
