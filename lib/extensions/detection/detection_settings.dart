import 'package:flutter/material.dart';
import '../../core/services/media_manager.dart';
import '../../core/orchestrator/extension_metadata.dart';

/// Detection setting enum.
// search = actively searching (a target exists; target could be all)
// position = include position information for detections
// color = include color information for detections
enum DetectionSetting {search, position, color}

/// DetectionSettings handles the user settings for a detection extension.
abstract class DetectionSettings {

  final Map<DetectionSetting, bool> _settingToggles;

  final ExtensionName _extensionName;
  final MediaManager _mediaManager;
  dynamic target; // the detection extension searching target; either specific or a representation of "all"

  ExtensionName get extensionName => _extensionName;
  bool? get search => _settingToggles[DetectionSetting.search];
  bool? get position => _settingToggles[DetectionSetting.position];
  bool? get color => _settingToggles[DetectionSetting.color];

  DetectionSettings(this._extensionName, this._settingToggles, this._mediaManager);

  /// Update position information toggle of search settings and give
  /// confirmation message. To correctly initiate settings commands,
  /// the user's transcription must begin with the word "settings,"
  /// followed by the word "report" to report settings, or a setting
  /// name and then "on" or "off" to toggle that setting.
  ///
  /// Parameters:
  ///   transcription - the current recording to process
  Future<bool> handleSettingCommands(String transcription) async {
    List<String> transcriptionArray = transcription.split(" ");
    debugPrint(transcriptionArray.toString());

    // flag for whether settings command was activated or not
    bool settingsActivated = false;

    // check if first word is "settings"; use substring to match even with : or ,
    if (transcriptionArray[0].length < 8 || transcriptionArray[0].substring(0, 8) != "settings") {
      return settingsActivated;
    }

    // once here: settings command was called
    settingsActivated = true;

    // check if transcription is "settings report"
    if (transcriptionArray.length < 2) {
      await _mediaManager.speak("Failed to update settings.");
      return settingsActivated;
    }
    String firstWord = transcriptionArray[1];
    if (firstWord == "report") {
      await announceSettings();
      return settingsActivated;
    }

    // check if transcription is a settings update
    if (transcriptionArray.length < 3) {
      await _mediaManager.speak("Failed to update settings.");
      return settingsActivated;
    }
    // determine setting to update
    DetectionSetting setting;
    try {
      setting = DetectionSetting.values.byName(firstWord);
    } catch (e) {
      await _mediaManager.speak(
          "Failed to update settings. $firstWord "
              "is not a valid setting for ${_extensionName.name} detection extension."
      );
      return settingsActivated;
    }
    // determine toggle value
    bool toggle;
    if (transcriptionArray[2] == "on") {
      toggle = true;
    } else if (transcriptionArray[2] == "off") {
      toggle = false;
    } else {
      await _mediaManager.speak(
          "Failed to update settings. "
              "New setting value must be either on or off."
      );
      return settingsActivated;
    }
    // check if attempting to turn on search: must instead provide target, which automatically turns on search
    if (setting == DetectionSetting.search && toggle == true) {
      await _mediaManager.speak("Failed to update settings. Give target to turn on search.");
      return settingsActivated;
    }

    // attempt to update setting
    bool settingsSuccessfullyUpdated = await updateSettings(setting, toggle);
    if (!settingsSuccessfullyUpdated) {
      await _mediaManager.speak("Failed to update settings.");
    }
    return settingsActivated;
  }

  /// Update setting toggle and give confirmation message.
  ///
  /// Parameters:
  ///   setting - the setting to update
  ///   toggle - true to turn the setting on, false otherwise
  Future<bool> updateSettings(DetectionSetting setting, bool toggle) async {
    bool settingsSuccessfullyUpdated = true;
    // update settings
    if (_settingToggles.keys.contains(setting)) {
      _settingToggles[setting] = toggle;
      // give confirmation message
      if (!(setting == DetectionSetting.search && toggle == true)) {
        await _mediaManager.speak(
            "${setting.name} ${toggle ? "on" : "off"}");
      }
    }
    else {
      settingsSuccessfullyUpdated = false;
    }
    return settingsSuccessfullyUpdated;
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

  /// A helper function for announceSettings that creates
  /// the message to announce the current search target.
  ///
  /// Parameters:
  ///   target: the current search target
  ///
  /// Returns: the message to announce the current search target
  String targetMessage(dynamic target);
}
