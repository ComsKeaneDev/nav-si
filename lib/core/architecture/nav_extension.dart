import 'dart:async';

// create an abstract class that manage the further extension
abstract class NavExtension {
  String get id;
  String get name;
  String get author;
  String get version => "1.0.0";

}