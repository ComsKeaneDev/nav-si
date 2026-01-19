import 'package:flutter/material.dart';
import '../../core/services/media_manager.dart';
import '../../core/orchestrator/extension_metadata.dart';

// enum DetectionTask {object, text}

// settings for a given detection extension
enum DetectionSetting {searchOn, position, color}

class DetectionSettings {

  // default search settings (color information only used for object detection)
  Map<DetectionSetting, bool> settingsMap = {
    DetectionSetting.searchOn: false,
    DetectionSetting.position: true,
    DetectionSetting.color: false
  };

  // info about associated detection extension
  late ExtensionName _name;
  late MediaManager _mediaManager;
  late BuildContext _context;

  get searchOn => settingsMap[DetectionSetting.searchOn];
  get position => settingsMap[DetectionSetting.position];
  get color => settingsMap[DetectionSetting.color];

  DetectionSettings(ExtensionName extensionName, MediaManager mediaManager, BuildContext buildContext) {
    _name = extensionName;
    _mediaManager = mediaManager;
    _context = buildContext;
  }

  /// Handle the user pressing the record button.
  ///
  /// Parameters:
  ///   onListeningResult - the callback function upon detected speech
  ///   onListeningDone - the callback function when listening finishes regardless of whether or not speech was detected
// Future<void> recordButtonPress(Future<void> Function(String) onListeningResult, Future<void> Function() onListeningDone) async {
//   await speaker.stop(); // stop current speech
//   await Future.delayed(Duration(milliseconds: 50));
//   // await speaker.speak("On");
//   await microphoneSource!.startListening(onListeningResult);
// }

  /// Update position information toggle of search settings
  /// and give confirmation message.
  ///
  /// Parameters:
  ///   currentRecording - the current recording to process
  ///   searchTargetMessage - message to announce the current search targets
  ///
  /// Returns: true if an update was made to the settings, and false otherwise
  Future<bool> handleSettingCommands(String currentRecording, String searchTargetMessage) async {
    bool settingsUpdated = true;

    switch (currentRecording) {
    // turning off search
      case "search off":
        await updateSetting(DetectionSetting.searchOn, false);
    // reporting current search info
      case "settings":
        await announceSettings(searchTargetMessage);
    // updating position information
      case "position on":
        await updateSetting(DetectionSetting.position, true);
      case "position off":
        await updateSetting(DetectionSetting.position, false);
      default:
        {
          if (_name == ExtensionName
              .object) { // only object detection has color information
            // updating color information
            if (currentRecording == "color on") {
              await updateSetting(DetectionSetting.color, true);
            }
            else if (currentRecording == "color off") {
              await updateSetting(DetectionSetting.color, false);
            }
          } else {
            settingsUpdated = false;
          }
        }
    }
    return settingsUpdated;

  }

  /// Update setting toggle and give confirmation message.
  ///
  /// Parameters:
  ///   setting - the setting to update
  ///   trueFalseToggle - true to turn the setting on, false otherwise
  Future<void> updateSetting(DetectionSetting setting, bool trueFalseToggle) async {
    // update settings
    settingsMap[setting] = trueFalseToggle;

    // confirmation message
    if (setting == DetectionSetting.searchOn) {
      if (!trueFalseToggle) {
        await _mediaManager.speak("Search turned off");
      }
    }
    else {
      await _mediaManager.speak("${setting.name} information ${trueFalseToggle? "on" : "off"}");
    }
  }

  /// Announce the current extension and settings
  /// (extension name, position information toggle, color information toggle, targets).
  ///
  /// Parameters:
  ///   - searchTargetMessage - message to announce the current search targets
  Future<void> announceSettings(String searchTargetMessage) async {

    String settingsMessage = "${_name.name} detection extension.";

    if (settingsMap[DetectionSetting.searchOn]!) {
      settingsMessage += " Position information: ${settingsMap[DetectionSetting.position]!? "on": "off"}.";
      if (_name == ExtensionName.object) {
        settingsMessage += " Color information: ${settingsMap[DetectionSetting.color]!? "on": "off"}.";
      }
      settingsMessage += " " + searchTargetMessage;
    } else {
      settingsMessage += " Search: off.";
    }

    await _mediaManager.speak(settingsMessage);

  }
}
