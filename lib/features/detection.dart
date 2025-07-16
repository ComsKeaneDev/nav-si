import '../main.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:math' hide log;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

// Detection mixin that provides common functions for object and text detection.
mixin Detection {
  /// default search settings
  Map<String, bool> searchSettings = {"searching": false, "position": true, "color": false};

  /// Update positional information toggle of search settings
  /// and give confirmation message.
  ///
  /// Parameters:
  ///   newSetting - true to turn positional information on,
  ///                false to turn positional information off
  ///
  /// Returns: true if an update was made to the settings, and false otherwise
  Future<bool> handleSettingCommands(String task, String currentRecording, BuildContext context, Function confirmationMessage) async {
    // updating task
    if (currentRecording == "switch to text detection") {
      await switchToTask("text", context);
      return true;
    }

    if (currentRecording == "switch to object detection") {
      await switchToTask("object", context);
      return true;
    }

    // turning off search
    if (currentRecording == "search off") {
      await turnOffSearch();
      return true;
    }

    // reporting current search info
    if (currentRecording == "search settings") {
      await getSearchSettings(confirmationMessage, task);
      return true;
    }

    // updating positional information
    if (currentRecording == "position on") {
      await updatePositionSetting(true);
      return true;
    }
    else if (currentRecording == "position off") {
      await updatePositionSetting(false);
      return true;
    }

    if (task == "object") {
      // updating color information
      if (currentRecording == "color on") {
        await updateColorSetting(true);
        return true;
      }
      else if (currentRecording == "color off") {
        await updateColorSetting(false);
        return true;
      }
    }

    return false;
  }

  /// Switch to new task.
  ///
  /// Parameters:
  ///   newTask: the task to switch to
  Future<void> switchToTask(String newTask, BuildContext context) async {
    context.push('/${newTask}_detection.dart');
  }

  /// Update positional information toggle of search settings
  /// and give confirmation message.
  ///
  /// Parameters:
  ///   newSetting - true to turn positional information on,
  ///                false to turn positional information off
  Future<void> updatePositionSetting(bool newSetting) async {
    if (newSetting) {
      searchSettings["position"] = true;
      await textToSpeech.speak("Positional information on");
    } else {
      searchSettings["position"] = false;
      await textToSpeech.speak("Positional information off");
    }
  }

  /// Update color information toggle of search settings
  /// and give confirmation message.
  ///
  /// Parameters:
  ///   newSetting - true to turn color information on,
  ///                false to turn color information off
  Future<void> updateColorSetting(bool newSetting) async {
    if (newSetting) {
      searchSettings["color"] = true;
      await textToSpeech.speak("Color information on");
    } else {
      searchSettings["color"] = false;
      await textToSpeech.speak("Color information off");
    }
  }

  /// Announce the current search settings
  /// (task, positional information toggle, color information toggle, target objects).
  Future<void> getSearchSettings(Function confirmationMessage, String task) async {
    await textToSpeech.speak("Search settings:");
    await textToSpeech.speak("Task: $task detection");
    if (searchSettings["searching"]!) {
      await textToSpeech.speak("Positional information: ${searchSettings["position"]!? "on": "off"}");
      if (task == "object") {
        await textToSpeech.speak("Color information: ${searchSettings["color"]!? "on": "off"}");
      }
      await confirmationMessage();
    } else {
      await textToSpeech.speak("Search: off");
    }
  }

  /// Stop searching and give confirmation message.
  Future<void> turnOffSearch() async {
    searchSettings["searching"] = false;
    await textToSpeech.speak("Search turned off");
  }

  /// Determine the position of a bounding box's center on the screen.
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
    // "cyan": Color.fromARGB(255, 0, 255, 255),
    // "magenta": Color.fromARGB(255, 255, 0, 255),
  };

  /// Finds the closest color to an object's color.
  ///
  /// Parameters:
  ///   frame: the current camera frame
  ///   boundingBox: the object's bounding box
  ///
  /// Returns: the closest color in colorPalette
  String calculateColor(Uint8List frame, Map boundingBox) {

    // to focus on center of object
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

    final frameWidth = decodedImage.width;
    for (int y = startY; y < endY; y += 1) {
      for (int x = startX; x < endX; x += 1) {
        redSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3)];
        greenSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3) + 1];
        blueSum += decodedImageRgb[(y * frameWidth * 3) + (x * 3) + 2];
      }
    }

    final area = (width * (1  - 2 * cropFraction)) * (height * (1  - 2 * cropFraction));

    final thisColor = Color.fromARGB(255,
        (redSum / area).round(), (greenSum / area).round(), (blueSum / area).round());

    var closestColor = "";
    num closestColorDistance = 195075; // 3 * 255^2

    for (var colorName in colorPalette.keys) {
      final otherColorRgb = colorPalette[colorName]!;
      final colorDistance = pow(otherColorRgb.r - thisColor.r, 2) +
          pow(otherColorRgb.g - thisColor.g, 2) +
          pow(otherColorRgb.b - thisColor.b, 2);

      if (colorDistance < closestColorDistance) {
        closestColorDistance = colorDistance;
        closestColor = colorName;
      }
    }

    return closestColor;
  }
}
