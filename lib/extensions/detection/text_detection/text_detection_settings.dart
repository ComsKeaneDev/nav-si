import '../../../core/orchestrator/extension_metadata.dart';
import '../../../core/services/media_manager.dart';
import '../detection_settings.dart';

/// TextDetectionSettings handles the user settings for the text detection extension.
class TextDetectionSettings extends DetectionSettings {

  TextDetectionSettings(MediaManager mediaManager)
  : super(
    ExtensionName.text,
      {DetectionSetting.search: false,
      DetectionSetting.position: true},
    mediaManager);

  @override
  String targetMessage(dynamic target) {
    // for text detection: target is a string
    // "" = all text, otherwise the string is the specific target text
    String targetString = target as String;
    return (targetString == "") ? 'Searching for all text' : 'Searching for: $targetString';
  }

}