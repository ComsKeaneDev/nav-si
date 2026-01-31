import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../../../core/services/media_manager.dart';
import '../../../core/services/camera/camera_source.dart';
import '../../../core/services/audio/microphone/microphone_source.dart';
import '../detection_settings.dart';
import '../detection_utils.dart';
import '../../../ui/widgets/speak_button.dart';
import 'object_detection_settings.dart';

// Extension metadata:
//  name: Object Detection
//  version: 1.0.0
//  author: Kailey Epstein
//  description: Search for surrounding objects, with the ability to detect all objects or specified targets (with optional position and color information).
//  permissions: camera (for mobile), microphone (for mobile)
//  camera sources: mobile, hardware
//  microphone sources: mobile, hardware

class ObjectDetection extends StatefulWidget {
  const ObjectDetection({super.key});

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

  @override
  State<ObjectDetection> createState() => _ObjectDetectionState();
}

class _ObjectDetectionState extends State<ObjectDetection> {

  // for media manager
  MediaManager? _mediaManager;
  // choose camera & microphone source types (mobile vs. hardware)
  final _cameraSourceType = CameraSourceType.mobile;
  final _microphoneSourceType = MicrophoneSourceType.mobile;

  ObjectDetectionSettings? _settings;

  // object detection model
  final yolo = YOLO(modelPath: "yolo11n", task: YOLOTask.detect);

  StreamSubscription<void>? _frameSubscription;
  bool _isProcessing = false;

  // for processImageResults
  Map<String, List> spokenLog = {}; // {(objectName : position), [int consecutiveTimesDetected, bool foundInThisFrame]}
  double targetRepeatPauseLength = 100.0; // how long to wait before announcing same target object again

  // for bounding boxes
  List<Map<String, dynamic>> _currentDetections = [];

  // toggle on/off ability to send JSON data of detected objects over network
  bool sendData = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Initialize camera and controller, set initial thresholds,
  /// and give confirmation of object detection task.
  Future<void> _initialize() async {
    // initialize media manager
    _mediaManager = MediaManager(
      cameraSourceType: _cameraSourceType,
      microphoneSourceType: _microphoneSourceType,
    );

    try {
      await _mediaManager!.initialize(_onListeningResult);

      if (mounted) { setState(() {}); }

      // initialize model
      await yolo.loadModel();

      // initialize settings
      _settings = ObjectDetectionSettings(_mediaManager!);

      await _mediaManager!.speak("Object detection extension.");
      await _startProcessing();

    } catch (e) {
      debugPrint("Initialization error: $e");
    }

  }

  /// Process speech to perform correct next step: switching extensions, updating
  /// settings, or updating search targets.
  ///
  /// Parameters:
  ///   transcription - the transcribed result of the user's speech
  Future<void> _onListeningResult(String transcription) async {

    // handle navigation
    if (transcription == "switch to text detection") {
      await _cleanup();

      if (context.mounted) {
        context.go('/text_detection.dart');
      }
      return;
    }

    // handle settings commands; start processing and return if settings updated
    if (await _settings!.handleSettingCommands(transcription)) {
      return;
    }

    // handle search update

    List<String> targetObjectList = [];
    // all objects
    if (transcription.contains("all objects")) {
      targetObjectList = [...ObjectDetection.objectList];
    }
    // select objects
    else {
      List<String> recordedWords = transcription.split(" ");
      for (int i = 0; i < recordedWords.length; i += 1) {
        // one-word objects
        if (ObjectDetection.objectList.contains(recordedWords[i])) {
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
          if (ObjectDetection.objectList.contains(twoPartWord)) {
            targetObjectList.add(twoPartWord);
          }
        }
      }
    }

    // set target objects
    if (targetObjectList.isNotEmpty) {
      await updateTargetObjects(targetObjectList);
      if (!(_settings!.search!)) {
        await _settings!.updateSettings(DetectionSetting.search, true);
      }
    } else {
      await _mediaManager!.speak("Failed to update search.");
    }
  }

  /// Update target objects and give confirmation message.
  ///
  /// Parameters:
  ///   newObjects: new objects to search for
  Future<void> updateTargetObjects(List<String> newObjects) async {
    _settings!.target = newObjects;
    await objectConfirmationMessage();
  }

  /// Give confirmation message of current target objects.
  Future<void> objectConfirmationMessage() async {
    List target = _settings!.target;
    // give confirmation message
    if (listEquals(target, ObjectDetection.objectList)) {
      await _mediaManager!.speak('Searching for all objects');
    }
    else {
      String spokenObjectList = target[0];
      if (target.length > 1) {
        for (String object in target.sublist(1, target.length)) {
          spokenObjectList += "; $object";
        }
      }
      await _mediaManager!.speak('Searching for: $spokenObjectList');
    }
  }

  /// Start text detection processing of camera frames.
  Future<void> _startProcessing() async {
    // return if already processing
    if (_frameSubscription != null) {
      return;
    }

    // create subscription to camera frames
    _frameSubscription = _mediaManager!.cameraSource!.frameStream
        .where((_) => _settings!.search!) // currently searching
        .listen((frame) async {
          if (_isProcessing) return; // drop frames if processing
          _isProcessing = true;

          try {
            await _processCameraFrame(frame);
          } finally {
            _isProcessing = false;
          }
        },
        onError: (error) {
          debugPrint("Frame processing error: $error");
        },
      );
  }

  /// Process a single camera frame to detect objects.
  ///
  /// Parameters:
  ///   frame: the camera frame to process
  Future<void> _processCameraFrame(CameraFrame frame) async {
    try {
      final image = await _mediaManager!.cameraSource!.createJpegImage(frame);
      final Map<String, dynamic> results = await yolo.predict(image, confidenceThreshold: 0.5, iouThreshold: 0.45);

      setState(() {
        _currentDetections = results["detections"];
      });

      await _processImageResults(image, results);
      debugPrint("Results: ${results["detections"]}");

    } catch (e) {
      debugPrint("Object detection error: $e");
    }
  }

  /// Processes image results to provide message about detected objects in current frame.
  ///
  /// Parameters:
  ///   frame: the current camera frame, used for color calculation
  ///   results: results of current detected objects
  Future<void> _processImageResults(Uint8List frame, Map<String, dynamic> results) async {

    // results.keys: fps, frameNumber, processingTimeMs, originalImage, detections, timestamp

    // initially set all logged objects to have not been found in this frame
    spokenLog.updateAll((key, value) => [value[0], false]);

    final List<String> targetObjects = _settings!.target!;

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
          debugPrint("Error: failed to send data.");
        }
      }

      bool foundInThisFrame = true;
      final String object = result["className"].toLowerCase();

      // categories for which no color description should be given
      final List<String> noColorDescription = ["person"];

      if (targetObjects.contains(object)) {

        // get object position if necessary - using normalized so frame width and height = 1
        var objectPosition = (_settings!.position!) ? "near ${calculatePosition(
            centerX: (result["normalizedBox"]["left"]! + ((result["normalizedBox"]["right"]! - result["normalizedBox"]["left"]!) / 2)),
            centerY: (result["normalizedBox"]["top"]! + ((result["normalizedBox"]["bottom"]! - result["normalizedBox"]["top"]!) / 2)),
            frameWidth: 1.0,
            frameHeight: 1.0)}"
            : "";

        // get color description if necessary
        var objectColor = "";
        if (!noColorDescription.contains(object) && _settings!.color!) {
          objectColor = calculateColor(frame, result["boundingBox"]);
        }

        // processing to determine whether to announce detection again
        final String objectKey = "$object : $objectPosition";
        if (spokenLog.containsKey(objectKey)) {
          if (spokenLog[objectKey]?[0] < targetRepeatPauseLength) { // increment timer and don't announce again
            spokenLog.update((objectKey) , (value) => [value[0] + 1, foundInThisFrame]);
          } else {
            spokenLog.update((objectKey) , (value) => [0, foundInThisFrame]); // reset timer and announce again
            await _mediaManager!.speak('Found: $objectColor $object $objectPosition');
          }
        } else {
          spokenLog[objectKey] = [0, foundInThisFrame]; // announce for first time
          await _mediaManager!.speak('Found: $objectColor $object $objectPosition');
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
  void dispose() {
    _cleanup();
    super.dispose();
  }

  /// Clean up the frame subscription, model, and media manager.
  Future<void> _cleanup() async {
    // cancel frame subscription
    await _frameSubscription?.cancel();
    _frameSubscription = null;

    // dispose model
    if (yolo.isInitialized) {
      await yolo.dispose();
    }

    // dispose media manager
    if (_mediaManager != null) {
      await _mediaManager!.dispose();
      _mediaManager = null;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      // record button
      floatingActionButton: SpeakButton(mediaManager: _mediaManager!),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // header
      appBar: AppBar(
        title: const Text('Object Detection'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),

      // camera preview
      body: _mediaManager == null || _mediaManager!.cameraSource == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [

          const SizedBox(height: 10),

          Expanded(
            child: _mediaManager!.cameraSource!.buildPreview(context),
          ),
        ],
      ),

    );
  }
}