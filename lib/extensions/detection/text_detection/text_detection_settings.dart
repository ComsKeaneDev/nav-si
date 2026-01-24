import '../../../core/orchestrator/extension_metadata.dart';
import '../../../core/services/media_manager.dart';
import '../detection_settings.dart';

class TextDetectionSettings extends DetectionSettings {

  TextDetectionSettings(MediaManager mediaManager)
  : super(
    ExtensionName.text,
      {DetectionSetting.search: false,
      DetectionSetting.position: true},
    mediaManager);

  @override
  String targetMessage(dynamic target) {
    String targetString = target as String;
    return (targetString == "") ? 'Searching for all text' : 'Searching for: $targetString';
  }

}