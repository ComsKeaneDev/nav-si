import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // for listEquals
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:flutter_vision/flutter_vision.dart';
import '../../core/architecture/nav_extension.dart';
import '../../core/utils/detection_utils.dart';
import '../object_detection.dart';


class YoloExtension extends NavExtension {
  @override
  String get id => "yolo_v1";
  @override
  String get name => "Object Detection";
  @override
  String get author => "Kailey";

  // controller
  ObjectDetector? _objectDetector;
  final StreamController<String> _outputController = StreamController<String>.broadcast();

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
  Future<void> initial() async {
    _vision = FlutterVision();

    _objectDetector = ObjectDetector(
      modelPath: '',
      metadataPath: ''
    );
    _objectDetector?.load();

    if (sendData) {
      targetObjects = [...objectList];
    }
  }

  @override
  Future<void> stop() async {
    _objectDetector?.close();
  }

  @override
  Future<void> processFrame(input) {
    // TODO: implement processFrame
    throw UnimplementedError();
  }

  @override
  // TODO: implement outputStream
  Stream<dynamic> get outputStream => throw UnimplementedError();
}


