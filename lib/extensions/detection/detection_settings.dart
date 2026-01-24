import '../../core/services/media_manager.dart';
import '../../core/orchestrator/extension_metadata.dart';

// settings for a given detection extension:
// search = actively searching (has a target; could be all)
// position = include position information for detections
// color = include color information for detections
enum DetectionSetting {search, position, color}

abstract class DetectionSettings {
  final Map<DetectionSetting, bool> _settingToggles;

  final ExtensionName _extensionName;
  final MediaManager _mediaManager;
  dynamic target;

  ExtensionName get extensionName => _extensionName;
  bool? get search => _settingToggles[DetectionSetting.search];
  bool? get position => _settingToggles[DetectionSetting.position];
  bool? get color => _settingToggles[DetectionSetting.color];

  DetectionSettings(this._extensionName, this._settingToggles, this._mediaManager);

  /// Update position information toggle of search settings
  /// and give confirmation message.
  ///
  /// Parameters:
  ///   transcription - the current recording to process
  Future<bool> handleSettingCommands(String transcription) async {
    List<String> transcriptionArray = transcription.split(" ");

    bool settingsCalledFlag = false;

    if (transcriptionArray[0] != "settings") {
      return settingsCalledFlag;
    }

    // settings command was called
    settingsCalledFlag = true;

    if (transcriptionArray.length < 2) {
      _mediaManager.speak("Failed to update settings.");
    }

    // settings report
    if (transcriptionArray[1] == "report") {
      await announceSettings();
      return settingsCalledFlag;
    }

    // update settings
    if (transcriptionArray.length < 3) {
      _mediaManager.speak("Failed to update settings.");
    }

    try {
      DetectionSetting setting = DetectionSetting.values.byName(transcriptionArray[1]);
      bool toggle;
      if (transcriptionArray[2] == "on") {
        toggle = true;
      } else if (transcriptionArray[2] == "off") {
        toggle = false;
      } else {
        _mediaManager.speak("Failed to update settings.");
        return settingsCalledFlag;
      }

      if (setting == DetectionSetting.search && toggle == true) {
        _mediaManager.speak("Give target to turn on search.");
        return settingsCalledFlag;
      }
      updateSetting(setting, toggle);
    } catch (e) {
      _mediaManager.speak("Failed to update settings.");
    }

    return settingsCalledFlag;
  }

  /// Update setting toggle and give confirmation message.
  ///
  /// Parameters:
  ///   setting - the setting to update
  ///   toggle - true to turn the setting on, false otherwise
  Future<void> updateSetting(DetectionSetting setting, bool toggle) async {
    // update settings
    _settingToggles[setting] = toggle;

    // give confirmation message
    if (!(setting == DetectionSetting.search && toggle == true)) {
      await _mediaManager.speak(
          "${setting.name} ${toggle ? "on" : "off"}");
    }
  }

  /// Announce the current extension name, settings, and target.
  Future<void> announceSettings() async {

    String settingsMessage = "Settings: ";

    settingsMessage += "${_extensionName.name} detection extension.";

    if (_settingToggles[DetectionSetting.search]!) {
      for (final setting in _settingToggles.keys) {
        settingsMessage += " ${setting.name} : ${_settingToggles[setting]!? "on": "off"}.";
      }
      settingsMessage += targetMessage(target);
    } else {
      settingsMessage += " Search: off.";
    }

    await _mediaManager.speak(settingsMessage);

  }

  String targetMessage(dynamic target);
}
