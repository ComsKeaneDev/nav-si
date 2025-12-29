import 'dart:async';

// create an abstract class that manage the further extension
abstract class NavExtension {
  String get id;
  String get name;
  String get author;
  String get version => "1.0.0";

  // Loop Management - model loaded and closed
  Future<void> initial();
  Future<void> stop();

  // process single frame data and give it output
  Future<void> processFrame(dynamic input);
  Stream<dynamic> get outputStream;
}