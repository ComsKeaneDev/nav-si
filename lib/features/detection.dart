import '../main.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:math' hide log;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:speech_to_text/speech_recognition_result.dart';

// detection tasks
enum Task {object, text}

// settings for a given task
enum Setting {search, position, color}

// Detection mixin that provides common functionalities for detection tasks.
mixin Detection {

  // default search settings (color information only used for object detection)
  Map<Setting, bool> settings = {Setting.search: false, Setting.position: true, Setting.color: false};

  /// Handle the user pressing the record button.
  ///
  /// Parameters:
  ///   onListeningResult - the callback function upon detected speech
  ///   onListeningDone - the callback function when listening finishes regardless of whether or not speech was detected
  Future<void> recordButtonPress(void Function(SpeechRecognitionResult) onListeningResult, Future<void> Function() onListeningDone) async {
    await textToSpeech.stop(); // stop current speech
    await Future.delayed(Duration(milliseconds: 50));
    await textToSpeech.speak("On");
    isListening = true;
    await speechToText.startListening(onListeningResult, onListeningDone);
  }

  /// Callback function when listening finishes, regardless of whether or not speech was detected.
  Future<void> onListeningDone() async {
    isListening = false;
  }

  /// Update position information toggle of search settings
  /// and give confirmation message.
  ///
  /// Parameters:
  ///   task - the current task
  ///   context - the build context of the current task
  ///   currentRecording - the recording to process
  ///   getConfirmationMessage - gives a confirmation message of the targets
  ///
  /// Returns: true if an update was made to the settings, and false otherwise
  Future<bool> handleSettingCommands(BuildContext context, String currentRecording, Function getConfirmationMessage) async {
    final Task task = getTask(context);

    // updating task
    bool settingsUpdated = false;
    if (currentRecording == "switch to text detection") {
      await switchToTask(Task.text, context);
      settingsUpdated = true;
    }
    else if (currentRecording == "switch to object detection") {
      await switchToTask(Task.object, context);
      settingsUpdated = true;
    }

    // turning off search
    else if (currentRecording == "search off") {
      await updateSetting(Setting.search, false);
      settingsUpdated = true;
    }

    // reporting current search info
    else if (currentRecording == "settings") {
      await announceSettings(context, getConfirmationMessage);
      settingsUpdated = true;
    }

    // updating position information
    else if (currentRecording == "position on") {
      await updateSetting(Setting.position, true);
      settingsUpdated = true;
    }
    else if (currentRecording == "position off") {
      await updateSetting(Setting.position, false);
      settingsUpdated = true;
    }

    else if (task == Task.object) { // only object detection has color information
      // updating color information
      if (currentRecording == "color on") {
        await updateSetting(Setting.color, true);
        settingsUpdated = true;
      }
      else if (currentRecording == "color off") {
        await updateSetting(Setting.color, false);
        settingsUpdated = true;
      }
    }

    return settingsUpdated;
  }

  /// Determine current task.
  ///
  /// Parameters:
  ///   context: the build context of the current task
  ///
  /// Returns: the current task
  Task getTask(BuildContext context) {
    final String currentUrl = GoRouterState.of(context).uri.toString();
    final task = currentUrl.substring(1, currentUrl.length - 15);
    return Task.values.firstWhere((val) => val.name == task);
  }

  /// Switch to new task and give confirmation message.
  ///
  /// Parameters:
  ///   newTask: the task to switch to
  ///   context: the build context of the current task
  Future<void> switchToTask(Task task, BuildContext context) async {
    settings[Setting.search] = false;
    await textToSpeech.stop(); // stop any current speech

    if (context.mounted) {
      context.push('/${task.name}_detection.dart');
    }
    await textToSpeech.speak("Task: ${task.name} detection", noLongerListening: true);
  }

  /// Determine if setting is on or off.
  ///
  /// Parameters:
  ///   - setting - the setting
  ///
  /// Returns: true if the setting is currently on, false otherwise
  bool getSetting(Setting setting) {
    return settings[setting]!;
  }

  /// Update setting toggle and give confirmation message.
  ///
  /// Parameters:
  ///   setting - the setting to update
  ///   toggle - true to turn the setting on, false otherwise
  Future<void> updateSetting(Setting setting, bool toggle) async {
    settings[setting] = toggle;

    // confirmation message
    if (setting == Setting.search) {
      if (!toggle) {
        await textToSpeech.speak("Search turned off", noLongerListening: true);
      }
    }
    else {
      await textToSpeech.speak("${setting.name} information ${toggle? "on" : "off"}", noLongerListening: true);
    }
  }

  /// Announce the current task and settings
  /// (task, position information toggle, color information toggle, targets).
  ///
  /// Parameters:
  ///   - getConfirmationMessage -
  ///   - task - the current task
  Future<void> announceSettings(BuildContext context, Function getConfirmationMessage) async {
    final Task task = getTask(context);

    await textToSpeech.speak("Task: ${task.name} detection", noLongerListening: true);
    if (settings[Setting.search]!) {
      await textToSpeech.speak("Position information: ${settings[Setting.position]!? "on": "off"}");
      if (task == Task.object) {
        await textToSpeech.speak("Color information: ${settings[Setting.color]!? "on": "off"}");
      }
      await getConfirmationMessage();
    } else {
      await textToSpeech.speak("Search: off");
    }
  }

  /// Determine the on-screen position of a bounding box's center.
  ///
  /// Parameters:
  ///   x: the x-coordinate of the center of the bounding box
  ///   y: the y-coordinate of the center of the bounding box
  ///   width: the screen's width
  ///   height: the screen's height
  ///
  /// Returns: a description of the location where the object is centered at
  ///   (1 of 9 quadrants: upper left edge, upper edge, upper right edge,
  ///   left edge, center, right edge, lower left edge, lower edge, lower right edge)
  String calculatePosition(dynamic centerX, dynamic centerY, double width, double height) {
    final String position;

    final widthFirstThird = 1/3 * width;
    final widthSecondThird = 2 * widthFirstThird;
    final heightFirstThird = 1/3 * height;
    final heightSecondThird = 2 * heightFirstThird;

    // top third
    if (centerY <= heightFirstThird) {
      if (centerX <= widthFirstThird) {
        position = "upper left edge";
      }
      else if (centerX > widthSecondThird) {
        position = "upper right edge";
      }
      else {
        position = "upper edge";
      }
    }
    // middle third
    else if (centerY > heightFirstThird && centerY <= heightSecondThird) {
      if (centerX <= widthFirstThird) {
        position = "left edge";
      }
      else if (centerX > widthSecondThird) {
        position = "right edge";
      }
      else {
        position = "center";
      }
    }
    // bottom third
    else {
      if (centerX <= widthFirstThird) {
        position = "lower left edge";
      }
      else if (centerX > widthSecondThird) {
        position = "lower right edge";
      }
      else {
        position = "lower edge";
      }
    }
    return position;
  }

  // color options for matching
  final colorPalette = {
    "black": Color.fromARGB(255, 0, 0, 0),
    "white": Color.fromARGB(255, 255, 255, 255),
    "red": Color.fromARGB(255, 255, 0, 0),
    "green": Color.fromARGB(255, 0, 255, 0),
    "blue": Color.fromARGB(255, 0, 0, 255),
    "yellow": Color.fromARGB(255, 255, 255, 0),
  };

  /// Finds the color in colorPalette that's the closest match to an object's color.
  ///
  /// Parameters:
  ///   frame: the current camera frame
  ///   boundingBox: the object's bounding box
  ///
  /// Returns: the closest color
  String calculateColor(Uint8List frame, Map boundingBox) {

    // to focus on center of object/ignore object edges for more accurate color info
    final cropFraction = 0.2;

    // bounding box information
    final width = (boundingBox["right"] - boundingBox["left"]).round();
    final height = (boundingBox["bottom"] - boundingBox["top"]).round();

    final startY = (boundingBox["top"] + (height * cropFraction)).round();
    final endY = (boundingBox["bottom"] - (height * cropFraction)).round();
    final startX = (boundingBox["left"] + (width * cropFraction)).round();
    final endX = (boundingBox["right"] - (width * cropFraction)).round();

    // decode image
    final decoder = image.JpegDecoder();
    final decodedImage = decoder.decode(frame) as image.Image;
    final decodedImageRgb = decodedImage.getBytes(order: image.ChannelOrder.rgb);

    // find pixel averages
    double redSum = 0;
    double greenSum = 0;
    double blueSum = 0;

    // calculate RGB sums of object
    final frameWidth = decodedImage.width;
    for (int y = startY; y < endY; y += 1) {
      for (int x = startX; x < endX; x += 1) {
        redSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3)];
        greenSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3) + 1];
        blueSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3) + 2];
      }
    }

    final area = (width * (1  - 2 * cropFraction)) * (height * (1  - 2 * cropFraction));

    // calculate object's average RGB color
    final objectColor = Color.fromARGB(255,
        (redSum / area).round(), (greenSum / area).round(), (blueSum / area).round());

    // find closest color in colorPalette
    var closestColor = "";
    num closestColorDistance = 195075; // 3 * 255^2

    for (var colorName in colorPalette.keys) {
      final otherColorRgb = colorPalette[colorName]!;
      final colorDistance = pow(otherColorRgb.r - objectColor.r, 2) +
          pow(otherColorRgb.g - objectColor.g, 2) +
          pow(otherColorRgb.b - objectColor.b, 2);

      if (colorDistance < closestColorDistance) {
        closestColorDistance = colorDistance;
        closestColor = colorName;
      }
    }

    return closestColor;
  }
}