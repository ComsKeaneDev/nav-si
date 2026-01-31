import 'package:flutter/foundation.dart';
import '../../../core/orchestrator/extension_metadata.dart';
import '../../../core/services/media_manager.dart';
import '../detection_settings.dart';
import '../object_detection/object_detection.dart';

/// ObjectDetectionSettings handles the user settings for the object detection extension.
class ObjectDetectionSettings extends DetectionSettings {

  ObjectDetectionSettings(MediaManager mediaManager)
  : super(
    ExtensionName.object,
      {DetectionSetting.search: false,
      DetectionSetting.position: true,
      DetectionSetting.color: false},
    mediaManager);

  @override
  String targetMessage(dynamic target) {
    // for object detection: target is a list
    List<String> targetList = target as List<String>;
    return (listEquals(targetList, ObjectDetection.objectList)) ? 'Searching for all objects' : 'Searching for: ${targetList.toString()}';
  }

}