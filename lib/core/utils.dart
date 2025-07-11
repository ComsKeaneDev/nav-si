import 'dart:ui';
import 'dart:math' hide log;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

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

/// Helper function for processDetectedObjects. Finds an object's closest color.
///
/// Parameters:
///   boundingBox: the object's bounding box
///
/// Returns: the closest color to the object's color
String calculateObjectColor(Uint8List frame, Map boundingBox) {

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