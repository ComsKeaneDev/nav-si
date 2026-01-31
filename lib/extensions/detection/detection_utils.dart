import 'dart:math' hide log;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

/// Determine the on-screen position of a bounding box's center.
///
/// Parameters:
///   centerX: the x-coordinate of the center of the bounding box
///   centerY: the y-coordinate of the center of the bounding box
///   width: the screen's width
///   height: the screen's height
///
/// Returns: a description of the location where the object is centered at
///   (1 of 9 quadrants: upper left edge, upper edge, upper right edge,
///   left edge, center, right edge, lower left edge, lower edge, lower right edge)
String calculatePosition({
  required dynamic centerX,
  required dynamic centerY,
  required double frameWidth,
  required double frameHeight
}) {
  final String position;

  final widthFirstThird = 1/3 * frameWidth;
  final widthSecondThird = 2 * widthFirstThird;
  final heightFirstThird = 1/3 * frameHeight;
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

/// Finds the color in colorPalette that's the closest match to an object's color
/// (accuracy varies based on lighting, etc.).
///
/// Parameters:
///   frame: the current camera frame
///   boundingBox: the object's bounding box
///
/// Returns: the closest color to the object
String calculateColor(Uint8List frame, Map boundingBox) {

  // to focus on center of object/ignore object edges for more accurate color info
  final cropFraction = 0.2;

  // bounding box information:
  // top = y-coordinate of top edge, left = x-coordinate of left edge,
  // bottom = y-coordinate of bottom edge, right = x-coordinate of right edge
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