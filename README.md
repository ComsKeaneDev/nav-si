# NAV-SI
## Project Structure (in progress)
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

## Models/Tools

### Object Detection:
- [Ultralytics YOLO 11n](https://docs.ultralytics.com/models/yolo11/) (loaded as Tensorflow Lite for Android & coreML for iOS)
- Task: detection

### Text Detection:
- [Google's ML Kit Text Recognition](https://pub.dev/packages/google_mlkit_text_recognition)

### Text to Speech:
- [flutter_tts](https://pub.dev/packages/flutter_tts) package

### Speech to Text:
- [speech_to_text](https://pub.dev/packages/speech_to_text) package

## Voice Control

NAV-SI works entirely through voice control (except for pressing the 'Record' button to start speaking).
Below are the steps and commands to follow (each ⟶ arrow indicates the verbal confirmation message after a prompt is given):

Before speaking (for all prompting steps below): to start recording press 'Record' ⟶ _"On"_

### Setting Commands:
- To switch tasks: "Switch to [object/text] detection" ⟶ _"Task: [object/text] detection"_
- To turn positional/color (only for object detection) information on/of: "[Position/color] [on/off]" → _"[Positional/Color] information [on/off]"_
    - Default: positional information on, color information off
- To receive a report on current search settings (task, positional/color information, current target): "Settings"
  ⟶ _"Settings: task: [object/text] detection, positional information: [on/off], [color information: [on/off]], searching for: ..."_
- To stop search: "Search off" ⟶ _"Search turned off"_

### Updating Search:
- Object detection: give a phrase containing the target object(s) or the words "all objects"
    - "I'm searching for my laptop and keys" ⟶ _"Searching for: laptop, keys"_
    - "Announce all objects around me" ⟶ _"Searching for all objects"_
- Text detection: give the exact target text or say "all text"
    - "stairs" ⟶ _"Searching for: stairs"_
    - "all text" ⟶ _"Searching for all text"_

### Troubleshooting:
- If your voice isn't being recognized, try to...
  - Speak right away after the "on" confirmation; if you wait too long, the voice recorder may turn off (in which case you can simply re-press the button and try again)
  - Speak loudly and close to the microphone
  - Speak clearly/enunciate your words

## Demos

Before speaking (for all prompting steps below): to start recording press 'Record' → _"On"_

### Object Detection
- Open app ⟶ _"Task: object detection"_  
**All objects**
- Say "Please announce all objects" ⟶ _"Searching for all objects"_
- Pan camera around ⟶ _i.e. "Found: laptop near center, found: backpack near lower right"_  
**Target objects**
- Say "I'm looking for a chair or bench to rest at" ⟶ _"Searching for: chair, bench"_
- Pan camera to find chairs ⟶ _i.e. "Found: chair near lower left edge, found: chair near center"_  
**Color detection**
- Say "Color on" ⟶ _"Color information on"_
- Pan camera to find chairs ⟶ _i.e. "Found: black chair near lower left edge, found: red chair near center"_

### Text Detection
- Open app ⟶ _"Task: object detection"_
- Say "Switch to text detection" ⟶ _"Task: text detection"_  
**All text**
- Say "All text" ⟶ _"Searching for all text"_
- Pan camera to find text ⟶ _i.e. "In case of fire, use stairs"_  
**Target text**
- Say "toilet" ⟶ _"Searching for: toilet"_
- Pan camera to find text ⟶ _i.e. "Found: toilet near upper edge"_

### Settings
- Open app ⟶ _"Task: object detection"_
- Say "Settings" ⟶ _"Settings: Task: object detection, search: off"_
- Say "Is there a person near me?" → _"Searching for: person"_
- Say "Settings" ⟶ _"Settings: Task: object detection, position information: on, color information: off, searching for: person"_
- Say "Color on" ⟶ _"Color information on"_
- Say "Settings" ⟶ _"Settings: Task: object detection, position information: on, color information: on, searching for: person"_
- Say "Search off" ⟶ _"Search turned off"_
- Say "Settings" ⟶ _"Settings: Task: object detection, search: off"_

## Future

### Next Steps:
- Test with iOS (currently only tested with Android)
- Reorganize into structure as described above
- Interface with AirPods/wireless earbuds (may require Kotlin)
- Add facial detection feature
- Add additional detection classes: bins, stairs, lift, etc.

### Adding Features:
- Create a new page in the features directory & add new path to router.dart

[//]: # (### Bugs:)

[//]: # (- All text + blank recording)

[//]: # (  - To replicate: switch to text detection task, search for all text, press 'Record' &#40;microphone turns on and search stops&#41; but don't say anything)

[//]: # (  - Result: once microphone times out & turns off again, search doesn't continue)

[//]: # (  - Reason: code is still behind from trying to process all text in each frame while microphone was on, even though nothing was being announced)