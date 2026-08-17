import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
//import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
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

  // plural to singular map
  static final Map<String, String> pluralToSingular = {
    "people":"person","bicycles":"bicycle","cars":"car","motorcycles":"motorcycle","airplanes":"airplane","buses":"bus","trains":"train","trucks":"truck",
    "boats":"boat","traffic lights":"traffic light","fire hydrants":"fire hydrant","stop signs":"stop sign","parking meters":"parking meter","benches":"bench","birds":"bird","cats":"cat",
    "dogs":"dog","horses":"horse","sheep":"sheep","cows":"cow","elephants":"elephant","bears":"bear","zebras":"zebra","giraffes":"giraffe",
    "backpacks":"backpack","umbrellas":"umbrella","handbags":"handbag","ties":"tie","suitcases":"suitcase","frisbees":"frisbee","skis":"ski","snowboards":"snowboard",
    "sports balls":"sports ball","kites":"kite","baseball bats":"baseball bat","baseball gloves":"baseball glove","skateboards":"skateboard","surfboards":"surfboard","tennis rackets":"tennis racket","bottles":"bottle",
    "wine glasses":"wine glass","cups":"cup","forks":"fork","knives":"knife","spoons":"spoon","bowls":"bowl","bananas":"banana","apples":"apple",
    "sandwiches":"sandwich","oranges":"orange","broccolis":"broccoli","carrots":"carrot","hot dogs":"hot dog","pizzas":"pizza","donuts":"donut","cakes":"cake",
    "chairs":"chair","couches":"couch","potted plants":"potted plant","beds":"bed","dining tables":"dining table","toilets":"toilet","tvs":"tv","laptops":"laptop",
    "mice":"mouse","remotes":"remote","keyboards":"keyboard","cell phones":"cell phone","microwaves":"microwave","ovens":"oven","toasters":"toaster","sinks":"sink",
    "refrigerators":"refrigerator","books":"book","clocks":"clock","vases":"vase","scissors":"scissors","teddy bears":"teddy bear","hair driers":"hair drier","toothbrushes":"toothbrush",
  };

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

  // controller - REVIEWED
  late final YOLOViewController _yoloController;
  Future<void>? initializeControllerFuture;

  // camera preview - REVIEWED
  late final YOLOView yoloView;
  bool isYoloViewVisible = false;
  //TODO: determine if isYoloViewVisible makes things better or worse

  // model
  String model = 'yolo11n';
  YOLOTask modelTask = YOLOTask.detect;

  // for processImageResults
  Map<String, List> spokenLog = {}; // {(objectName : position), [int consecutiveTimesDetected, bool foundInThisFrame]}
  double targetRepeatPauseLength = 100.0; // how long to wait before announcing same target object again

  // for bounding boxes
  final List<Map<String, dynamic>> _currentDetections = [];

  // reset counter used to ignore stale processing after a manual reset
  int _resetCounter = 0;

  // toggle on/off ability to send JSON data of detected objects over network
  bool sendData = false;

  bool get isListening => _mediaManager?.microphoneSource?.state == MicrophoneState.activeListening;

  bool _isResultCurrent(int resetVersion, int micSessionId) {
    return resetVersion == _resetCounter &&
        micSessionId == (_mediaManager?.microphoneSessionId ?? 0) &&
        !isListening &&
        !(_mediaManager?.microphoneStarting ?? false);
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Initialize camera and controller, set initial thresholds,
  /// and give confirmation of object detection task.
  Future<void> _initialize() async {
    // initialize media manager (don't initialize camera, YOLOView handles it) - REVIEWED
    _mediaManager = MediaManager(
      cameraSourceType: _cameraSourceType,
      microphoneSourceType: _microphoneSourceType,
    );

    try {
      await _mediaManager!.initialize(_onListeningResult, includeCamera: false); // REVIEWED

      if (mounted) { setState(() {}); }

      // ensure camera permission is granted before initializing controller
      //await Permission.camera.request().isGranted;

      // initialize controller and set initial thresholds
      _yoloController = YOLOViewController();
      initializeControllerFuture = _yoloController.setThresholds(
        confidenceThreshold: 0.5,
        iouThreshold: 0.45,
      );

      // initialize camera view
      yoloView = YOLOView(
        controller: _yoloController,
        task: modelTask,
        modelPath: model,
        streamingConfig: YOLOStreamingConfig(
          includeOriginalImage: true, // frames for color detection
        ),
        onStreamingData: (results) async {
          if (_settings!.search! && !isListening && !(_mediaManager?.microphoneStarting ?? false)) {
            await _processImageResults(results, _resetCounter);
          }
        },
      );

      // ensure camera preview appears
      setState(() {
        isYoloViewVisible = true;
      });

      // initialize settings
      _settings = ObjectDetectionSettings(_mediaManager!);

      await _mediaManager!.speak("Object detection extension.");

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

    //TESTING: handle case where transcription is empty
    if (transcription == "") {
      await _mediaManager!.speak("Empty transcription heard.");
      return;
    }

    // handle navigation
    if (transcription.contains("text detection")) {
      _settings!.setSearchSilently(false);
      _resetCounter += 1;
      await _mediaManager!.stopSpeaking();
      await _mediaManager!.speak("Switching to text detection. Please wait.");
      await _cleanup();

      if (!mounted) return;
      context.pushReplacement('/text_detection.dart'); //TODO: check .go versus .pushReplacement
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

        String word = recordedWords[i];

        if (ObjectDetection.objectList.contains(word) || ObjectDetection.pluralToSingular.containsKey(word)) {
          
          word = !ObjectDetection.objectList.contains(word) ? ObjectDetection.pluralToSingular[word]! : word;
          
          targetObjectList.add(word);
          // don't add duplicate of bear along with teddy bear or of dog along with hot dog
          if ((word == "bear" && i > 0 && recordedWords[i - 1] == "teddy") ||
              (word == "dog" && i > 0 && recordedWords[i - 1] == "hot")) {
            targetObjectList.remove(word);
          }
        }

        // two-word objects
        else if ((i < recordedWords.length - 1)) {
          String twoPartWord = "${recordedWords[i]} ${recordedWords[i + 1]}";
          if (ObjectDetection.objectList.contains(twoPartWord)) {
            targetObjectList.add(twoPartWord);
          } else if (ObjectDetection.pluralToSingular.containsKey(twoPartWord)) {
            targetObjectList.add(ObjectDetection.pluralToSingular[twoPartWord]!);
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
      String message = "Failed to update search. No target objects mentioned.";
      if (_settings!.echo!) {
        message += " I heard: $transcription";
      }
      await _mediaManager!.speak(message);
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

  /// Processes image results to provide message about detected objects in current frame.
  ///
  /// Parameters:
  ///   results: results of current detected objects
  Future<void> _processImageResults(Map<String, dynamic> results, int resetVersion) async { //UNREVIEWED

    final int micSessionId = _mediaManager?.microphoneSessionId ?? 0;
    if (!_isResultCurrent(resetVersion, micSessionId)) {
      return;
    }

    // results.keys: fps, frameNumber, processingTimeMs, originalImage, detections, timestamp

    // initially set all logged objects to have not been found in this frame
    spokenLog.updateAll((key, value) => [value[0], false]);

    final List<String> targetObjects = _settings!.target!;
    final Uint8List? frame = results["originalImage"];

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
        if (!noColorDescription.contains(object) && _settings!.color! && frame != null) { //REVIEWED
          objectColor = calculateColor(frame, result["boundingBox"]);
        }

        // processing to determine whether to announce detection again
        final String objectKey = "$object : $objectPosition";
        if (spokenLog.containsKey(objectKey)) {
          if (spokenLog[objectKey]?[0] < targetRepeatPauseLength) { // increment timer and don't announce again
            spokenLog.update((objectKey) , (value) => [value[0] + 1, foundInThisFrame]);
          } else {
            spokenLog.update((objectKey) , (value) => [0, foundInThisFrame]); // reset timer and announce again
            if (!_isResultCurrent(resetVersion, micSessionId)) {
              return;
            }
            await _mediaManager!.speak('Found: $objectColor $object $objectPosition');
          }
        } else {
          spokenLog[objectKey] = [0, foundInThisFrame]; // announce for first time
          if (!_isResultCurrent(resetVersion, micSessionId)) {
            return;
          }
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
    // REVIEWED: stop controller and wait for native resources to release
    await _yoloController.stop();
    //TODO: find workarounds to the line below that don't involve hard-coded sleep times
    await Future.delayed(const Duration(milliseconds: 500)); //formerly 300

    // dispose media manager
    if (_mediaManager != null) {
      await _mediaManager!.dispose();
      _mediaManager = null;
    }
  }

  Future<void> _onResetPressed() async {
    if (_mediaManager == null) {
      return;
    }

    _resetCounter += 1;
    await _mediaManager!.stopSpeaking();

    setState(() {
      spokenLog.clear();
      _currentDetections.clear();
    });
  }

  Widget _buildResetButton() => FloatingActionButton(
        onPressed: _onResetPressed,
        heroTag: 'resetButton',
        backgroundColor: Colors.deepPurple.shade100,
        foregroundColor: Colors.white,
        child: const Text(
          'R',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      );

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      // record button
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildResetButton(),
          const SizedBox(width: 16),
          SpeakButton(mediaManager: _mediaManager!),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // header
      appBar: AppBar(
        title: const Text('Object Detection'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),

        // camera preview
        body: initializeControllerFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      Expanded(
                        child: isYoloViewVisible ? yoloView : Container(),
                      ),
                    ],
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }
} 
