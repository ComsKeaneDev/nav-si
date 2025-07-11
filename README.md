# All Brawn No Brains
## Project structure
```text
lib/
├── core/
│   ├── services/
│   ├── orchestrator/
│   └── models/
│
├── features/
│   ├── face_recognition/
│   ├── object_detection/
│   └── ocr/
│
├── state/
│
└── ui/
```

-   **core/**  
    Shared utilities: camera, audio, ML engine abstractions; the “brain” that wires tasks together; and simple DTOs.
    
-   **features/**  
    One sub-folder per model feature (that’s where the code lives to detect, embed, classify, store, etc.)
    
-   **state/**  
    The state management layer (BLoC/Provider/Riverpod ??) that sits between the orchestrator and anything that “listens” (UI, headphones, haptics).
    
-   **ui/**  
    Screens and widgets. In the future this will be minimal but right now it holds Flutter views.

###  core/
###### services/
Low-level wrappers around platform APIs. 
- ##### Camera service
  - Camera services that expose a single stream of input frames
  - Handles permission requests, camera resolution setups, and image format conversions
- #### Audio service
  - Manages voice input from headphones (or taps from AirPods)
  - Sends a stream of voice data 
- #### Model engine
  - Manages loading of models in TFlite, CoreML, or other formats ?
  - Should provide an async/future runModel API so each feature doesn't need to handle the model format

###### orchestrator/
Coordinates which “tasks” are active, passes camera frames & voice commands, and fetches results.
- #### Producer
  - Registers services and factories for each task (if identify face instantiate a face recognition task handler)
- #### Orchestrator
  - Holds a list of all implemented tasks (with associated IDs)
    task_orchestrator.dart
  - Listens for frames and voice commands. When a "change task to x" command arrives, it initialises tasks[x]. On each frame, a task.run(frame) is called (could even be multiple tasks. e.g. identification/face recognition could always be running in certain scenarios)
  - Should expose a stream of results to which some consumer can subscribe (e.g. a consumer listening for familiar faces needs to know when a familiar face appears and then go through some notification logic)
###### models/
Data objects shared across the app.
- #### Task result
  - Base class for results.
  - Subclasses like FaceResult (contains name, confidence, boundingBox), OcrResult, etc.


### features/
Each feature folder implements exactly one Task. e.g.
```text
features/
└── face_recognition/
    ├── face_task.dart
    ├── face_detector.dart
    ├── face_embedder.dart
    └── face_search.dart
```
- Implements a shared Task interface.
- Coordinates subcomponents (e.g. detector → embedder → vector search)
### state/
Connects the UI/events layer with the processing backend. Need to figure out what the best way to manage states is (options seem to be BLoC/Provider/Riverpod). 

### ui/
Contains any UI widgets that we make during testing. The final UI is going to change over time, but users should mostly rely on voice control.

### misc/ 
The stuff that was already there (YOLO demo and the websocket testing)


## Models

### Object detection:
- [Ultralytics YOLO 11n](https://docs.ultralytics.com/models/yolo11/) (loaded as Tensorflow Lite for Android & coreML for iOS)
- Task: detection

### Text detection:
- [Google ML Kit Text Detection](https://pub.dev/packages/google_mlkit_text_recognition)

## Voice control

1) Press 'Record' button (will receive confirmation of "on")

### Basic commands:
- To switch tasks: "Switch to [object/text] detection"
- To receive a report on current search settings: "Search settings"
- To turn positional/color (only for object detection) information on/of: "[Position/Color] [on/off]"
    - Default: positional information on, color information off

### Updating search:
- Object detection: give a phrase containing the target object(s) or the words "all objects"
    - "I'm searching for my laptop and keys"
    - "Announce all objects around me"
- Text detection: give the exact target text ("stairs") or say "all text"
    - "stairs"
    - "all text"