// - #### Orchestrator
// - Holds a list of all implemented tasks (with associated IDs)
// - Listens for frames and voice commands. When a "change task to x" command arrives, it initialises tasks[x]. On each frame, a task.run(frame) is called (could even be multiple tasks. e.g. identification/face recognition could always be running in certain scenarios)
// - Should expose a stream of results to which some consumer can subscribe (e.g. a consumer listening for familiar faces needs to know when a familiar face appears and then go through some notification logic)

import '../services/camera/camera_source.dart';
import '../services/audio/microphone/microphone_source.dart';

enum ExtensionName { text, object } // etc
enum LicenseType { mit } // etc
enum Permissions { microphone, camera, notifications, location}

class Requirements {

}

class TechnicalInfo {
  final int fps;
  // Input and output stream types
  // Memory usage
  // Blocking vs. non-blocking

  TechnicalInfo({
    required this.fps,
  });

}

class ExtensionMetadata {
  final ExtensionName name;
  final String version;
  final DateTime releaseDate;
  final List<String> authors;
  final LicenseType license;
  final String description; // what it does
  final List<Permissions> permissions;
  final List<CameraSourceType> cameraSources;
  final List<MicrophoneSourceType> microphoneSources;
  final TechnicalInfo technicalInfo;
  final List<ExtensionMetadata> attributions;
  final bool live;

  ExtensionMetadata({
    required this.name,
    required this.version,
    required this.releaseDate,
    required this.authors,
    required this.license,
    required this.description,
    required this.permissions,
    required this.cameraSources,
    required this.microphoneSources,
    required this.technicalInfo,
    required this.attributions,
    required this.live,
  });

}

// Status: {dict of booleans: (most_recent_version: true/false, live/active: true/false)}
// [New?] model used, api used, etc. (is this dependencies?)
// Requirements: dict
  // necessary profile (teacher vs. student vs. user, etc.): true/false
  // Certain app update version, etc.
