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
  String get author => "Dawei";

  // controller
  late FlutterVision _vision;
  final StreamController<String> _outputController = StreamController.broadcast();
  bool _isModelLoaded = false;

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

  bool isPositionOn = true;

  final StreamController<List<Map<String, dynamic>>> _resultsController = StreamController.broadcast();
  Stream<List<Map<String, dynamic>>> get resultsStream => _resultsController.stream;

  @override
  Future<void> initial() async {
    _vision = FlutterVision();
    // TODO: Hard code for now need to change
    await _vision.loadYoloModel(
      modelPath: 'assets/models/yolo11n.tflite',
      labels: 'assets/models/labels.txt',
      modelVersion: 'yolov11',
      quantization: false,
      numThreads: 1,
      useGpu: false,
    );
    _isModelLoaded = true;

    if (!sendData) {
      targetObjects = [...objectList];
    }
  }

  @override
  Future<void> stop() async {
    _isModelLoaded = false;
    await _vision.closeYoloModel();
    _outputController.close();
    _resultsController.close();
  }

  /// Validate bounding box dimensions are reasonable
  bool _isValidBoundingBox(double left, double top, double right, double bottom, int imgWidth, int imgHeight) {
    final width = right - left;
    final height = bottom - top;

    // Check if box has valid dimensions
    if (width <= 0 || height <= 0) return false;

    // Check if box is too small (likely noise)
    final minSize = 20.0;  // Minimum 20 pixels
    if (width < minSize || height < minSize) return false;

    // Check if box is too large (likely false positive)
    final maxSizeRatio = 0.9;  // Max 80% of image
    if (width > imgWidth * maxSizeRatio || height > imgHeight * maxSizeRatio) return false;

    return true;
  }

  @override
  Future<void> processFrame(dynamic input) async {
    if (!_isModelLoaded) return;

    // 🔴 添加调试信息
    print("📷 处理帧: ${input.width}x${input.height}, 格式: ${input.format}");
    print("📷 Planes数量: ${input.planes.length}");
    for (int i = 0; i < input.planes.length; i++) {
      print("  Plane $i 大小: ${input.planes[i].bytes.length}");
    }

    final List<Uint8List> bytesList = List<Uint8List>.from(
        input.planes.map((plane) => plane.bytes)
    );

    print("🔍 调用 yoloOnFrame，阈值: conf=0.5, class=0.5");

    // process result frame by flutter_vision
    // Increased thresholds to reduce false positives
    final results = await _vision.yoloOnFrame(
      bytesList: bytesList,
      imageHeight: input.height,
      imageWidth: input.width,
      iouThreshold: 0.45,
      confThreshold: 0.25,
      classThreshold: 0.25
    );

    // 🔴 添加详细日志
    print("📊 yoloOnFrame 返回结果数量: ${results.length}");
    if (results.isEmpty) {
      print("⚠️ 警告: 模型没有返回任何检测结果");
      print("   可能原因: 1) 阈值太高 2) 图片格式问题 3) 场景中无物体");
    } else {
      print("✅ 检测到 ${results.length} 个物体:");
      for (var result in results) {
        final box = result['box'] as List<dynamic>;
        final confidence = box.length >= 5 ? (box[4] as num).toDouble() : 0.0;
        print("  - ${result['tag']}: ${(confidence * 100).toStringAsFixed(1)}%");
      }
    }

    if (results.isNotEmpty) {
      _resultsController.add(results);
    } else {
      _resultsController.add([]);
    }

    // initially set all logged objects to have not been found in this frame
    spokenLog.updateAll((key, value) => [value[0], false]);

    // result analysis
    for (var result in results) {
      /// flutter_vision result has structure like:
      /// {
      ///   "box": [x1, y1, x2, y2, confidence],
      ///   "tag": "person"
      /// }

      bool foundInThisFrame = true;
      String? messageToSpeak;

      // get name and tag
      final String objectRaw = result['tag'].toString();
      final String object = objectRaw.toLowerCase();

      // get position and confidence
      final box = result['box'] as List<dynamic>;
      final double left = (box[0] as num).toDouble();
      final double top = (box[1] as num).toDouble();
      final double right = (box[2] as num).toDouble();
      final double bottom = (box[3] as num).toDouble();

      // Validate bounding box dimensions
      // Reject detections with invalid or unreasonable bounding boxes
      if (!_isValidBoundingBox(left, top, right, bottom, input.width, input.height)) {
        continue; // Skip this detection
      }

      // only detect items in targetObjects
      if (targetObjects.contains(object)) {

        // calculate position, using the calculatePosition
        final double centerX = left + (right - left) / 2;
        final double centerY = top + (bottom - top) / 2;
        String objectPosition = "";
        if (isPositionOn) {
          final posDescription = DetectionUtils.calculatePosition(
              centerX, centerY, input.width.toDouble(), input.height.toDouble());
          objectPosition = "near $posDescription";
        }

        /// TODO: calculate colour
        /// calculateColor need RGB image, but input now is YUV.
        /// need to implement later. Can use img.Image.fromBytes
        String objectColor = "";

        // processing to determine whether to announce detection again
        final String objectKey = "$object : $objectPosition";
        if (spokenLog.containsKey(objectKey)) {
          if (spokenLog[objectKey]?[0] < targetRepeatPauseLength) { // increment timer and don't announce again
            spokenLog.update((objectKey) , (value) => [value[0] + 1, foundInThisFrame]);
          } else {
            spokenLog.update((objectKey) , (value) => [0, foundInThisFrame]); // reset timer and announce again
            messageToSpeak = 'Found: $objectColor $object $objectPosition';
          }
        } else {
          spokenLog[objectKey] = [0, foundInThisFrame]; // announce for first time
          messageToSpeak = 'Found: $objectColor $object $objectPosition';
        }

        if (messageToSpeak != null) {
          final cleanMessage = messageToSpeak.replaceAll("  ", " ").trim();
          _outputController.add(cleanMessage);
        }
      }
    }
    spokenLog.removeWhere((key, value) => value[1] == false);
  }

  @override
  Stream<dynamic> get outputStream => _outputController.stream;
}


