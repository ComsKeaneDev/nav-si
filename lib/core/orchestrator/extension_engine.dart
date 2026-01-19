// - #### Orchestrator
// - Holds a list of all implemented tasks (with associated IDs)
// task_orchestrator.dart
// - Listens for frames and voice commands. When a "change task to x" command arrives, it initialises tasks[x]. On each frame, a task.run(frame) is called (could even be multiple tasks. e.g. identification/face recognition could always be running in certain scenarios)
// - Should expose a stream of results to which some consumer can subscribe (e.g. a consumer listening for familiar faces needs to know when a familiar face appears and then go through some notification logic)

import 'extension_metadata.dart';
import '../services/media_manager.dart';

class ExtensionEngine {
  // final Map<ExtensionName, ExtensionMetadata> availableExtensions = {
  //   ExtensionName.text: TextDetection.metadata,
  //   ...
  // };

  final MediaManager _mediaManager;
  final Map<ExtensionName, ExtensionMetadata> _activeExtensions = {

  };

  Map<ExtensionName, ExtensionMetadata> get activeExtensions => _activeExtensions;

  // like the extension engine

  ExtensionEngine(this._mediaManager);

  Future<void> initializeExtension(ExtensionName extensionName) async {
    // switch to task (extensionName)
    // or initialize? is starting task different than initializing?

    // add to list of activeExtensions

    // am I initializing the task and then passing the stream of frames?
    // or do I have the stream of frames and am calling task.run(frame) on each one?
  }

  Future<void> closeExtension(ExtensionName extensionName) async {
    // if extension is active: close extension

    // remove from list of activeExtensions
  }

}