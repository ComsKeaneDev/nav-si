# NAV-SI: Navigation And Visio-Spatial Information

# Overview

---

NAV-SI is an AI-based mobile app that performs object and text detection to enhance micro-navigation and environmental awareness for (particularly blind or visually impaired) users. NAV-SI runs in real-time, on-device, and through voice control.
- Tasks (with the ability to detect all in surrounding or specified):
  - object detection (labeled bounding boxes + position & color information)
  - text detection (position information (for specific text only)) 

# Project Structure (in progress)

---

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

##  core/
### services/
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

### orchestrator/
Coordinates which “tasks” are active, passes camera frames & voice commands, and fetches results.
- #### Producer
  - Registers services and factories for each task (if identify face instantiate a face recognition task handler)
- #### Orchestrator
  - Holds a list of all implemented tasks (with associated IDs)
    task_orchestrator.dart
  - Listens for frames and voice commands. When a "change task to x" command arrives, it initialises tasks[x]. On each frame, a task.run(frame) is called (could even be multiple tasks. e.g. identification/face recognition could always be running in certain scenarios)
  - Should expose a stream of results to which some consumer can subscribe (e.g. a consumer listening for familiar faces needs to know when a familiar face appears and then go through some notification logic)
### models/
Data objects shared across the app.
- #### Task result
  - Base class for results.
  - Subclasses like FaceResult (contains name, confidence, boundingBox), OcrResult, etc.


## features/
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

## state/
Connects the UI/events layer with the processing backend. Need to figure out what the best way to manage states is (options seem to be BLoC/Provider/Riverpod). 

## ui/
Contains any UI widgets that we make during testing. The final UI is going to change over time, but users should mostly rely on voice control.

## misc/ 
The stuff that was already there (YOLO demo and the websocket testing)

# Models/Tools

---

NAV-SI is built in Flutter with the Dart programming language.

### Object Detection:
- [Ultralytics YOLO 11n](https://docs.ultralytics.com/models/yolo11/) (loaded as Tensorflow Lite for Android & coreML for iOS)
- Task: detection

### Text Detection:
- [Google's ML Kit Text Recognition](https://pub.dev/packages/google_mlkit_text_recognition)

### Text to Speech:
- [flutter_tts](https://pub.dev/packages/flutter_tts) package

### Speech to Text:
- [speech_to_text](https://pub.dev/packages/speech_to_text) package

# Voice Control

---

NAV-SI works entirely through voice control (except for pressing the 'Record' button to start speaking).
Below are the steps and commands to follow (each ⟶ arrow indicates the verbal confirmation message after a prompt is given):

Before speaking (for all prompting steps below): to start recording press 'Record' ⟶ _"On"_

## Setting Commands:
- To switch tasks: "Switch to [object/text] detection" ⟶ _"Task: [object/text] detection"_
- To turn positional/color (only for object detection) information on/of: "[Position/color] [on/off]" → _"[Positional/Color] information [on/off]"_
    - Default: positional information on, color information off
- To receive a report on current search settings (task, positional/color information, current target): "Settings"
  ⟶ _"Settings: task: [object/text] detection, positional information: [on/off], [color information: [on/off]], searching for: ..."_
- To stop search: "Search off" ⟶ _"Search turned off"_

## Updating Search:
- Object detection: give a phrase containing the target object(s) or the words "all objects"
    - "I'm searching for my laptop and keys" ⟶ _"Searching for: laptop, keys"_
    - "Announce all objects around me" ⟶ _"Searching for all objects"_
- Text detection: give the exact target text or say "all text"
    - "stairs" ⟶ _"Searching for: stairs"_
    - "all text" ⟶ _"Searching for all text"_

## Troubleshooting:
- If your voice isn't being recognized, try to...
  - Speak right away after the "on" confirmation; if you wait too long, the voice recorder may turn off (in which case you can simply re-press the button and try again)
  - Speak loudly and close to the microphone
  - Speak clearly/enunciate your words
- If the 'Record' button isn't responding when pressed (no 'On' verification)...
    * this sometimes happens when speaking is in progress
    - Try to press again
    - Cover the camera with your hand so all speaking stops & try again

# Demos

---

Before speaking (for all prompting steps below): to start recording press 'Record' ⟶ _"On"_

## Object Detection
- Open app ⟶ _"Task: object detection"_  
**All objects**
- Say "Please announce all objects" ⟶ _"Searching for all objects"_
- Pan camera around ⟶ _e.g. "Found: laptop near center, found: backpack near lower right"_  
**Target objects**
- Say "I'm looking for a chair or bench to rest at" ⟶ _"Searching for: chair, bench"_
- Pan camera to find chairs ⟶ _e.g. "Found: chair near lower left edge, found: chair near center"_  
**Color detection**
- Say "Color on" ⟶ _"Color information on"_
- Pan camera to find chairs ⟶ _e.g. "Found: black chair near lower left edge, found: red chair near center"_

## Text Detection
- Open app ⟶ _"Task: object detection"_
- Say "Switch to text detection" ⟶ _"Task: text detection"_  
**All text**
- Say "All text" ⟶ _"Searching for all text"_
- Pan camera to find text ⟶ _e.g. "In case of fire, use stairs"_  
**Target text**
- Say "toilet" ⟶ _"Searching for: toilet"_
- Pan camera to find text ⟶ _e.g. "Found: toilet near upper edge"_

## Settings
- Open app ⟶ _"Task: object detection"_
- Say "Settings" ⟶ _"Task: object detection, search: off"_
- Say "Is there a person near me?" ⟶ _"Searching for: person"_
- Say "Settings" ⟶ _"Task: object detection, position information: on, color information: off, searching for: person"_
- Say "Color on" ⟶ _"Color information on"_
- Say "Settings" ⟶ _"Task: object detection, position information: on, color information: on, searching for: person"_
- Say "Search off" ⟶ _"Search turned off"_
- Say "Settings" ⟶ _"Task: object detection, search: off"_

# Misc

---

## Sending Object Detection Data:
- To turn JSON data sending on/off: update bool sendData in object_detection.dart
  - Can't be changed by user (only developer)
- To update IP address: change at comment "change IP address here" in object_detection.dart

# Future

---

### Next Steps
- Test with iOS (currently only tested on Android phone)
- Reorganize into mode organization/new app structure as described above
  - Currently: Detection mixin & 1 file/class per feature
- Add LLM layer between voice prompting & switching between features
- Add haptic feedback
- Make entirely contactless
  - Interface with wearable camera hardware
  - Use AirPods/wireless earbuds (microphone, buttons)
  - Remove all button UI elements
- To add feature: add capability!!

### Modes Organization
  1. Multiclass detection & spatial awareness/visual question-answering (current)
     - Add distance/depth calculations to all object detection
     - Add facial detection 
     - Add bus stop detection
     - Add car identification (user provides specific make & model; compile & embed Internet images to compare cars)
     - Add additional custom datasets to create new object detection classes: bins, stairs, lift, etc. & allow for custom detection
     - Make augmented datasets: use classification paths (TV, TV, TV, laptop, TV) to combat mislabeling & then reclassify so system can build own training dataset to boost own performance
  2. Ask for navigational help & receive real-time intervention
     - Expert data collection mode: take video clips & record notes (contextual expertise) for students while out in the world in various local settings/scenarios
     - Student help mode: asking for help from AI instructor trained on data collection & get intervention in moment (contextual inference based on scenario)
  3. Record video evidence for & report navigational issues
     - Capture, distill, report/distribute issues 
  4. *Sonification: take video stream pixels, quantize image, sonify

### New App Structure

#### Idea
- Set of users with a set of named profiles
- Each profile contains a set of capabilities (modes: object detection, text detection, data collection, student help mode, etc.)
  - Some capabilities will require user consent forms
- Each capability can be configured with different parameters

#### UI
- Home page
- Profile library/manager/editor/previewer
- Capability library/manager/editor/previewer/documentation
- Study library/manager
  
[//]: # (## To Add Features &#40;Currently&#41;:)

[//]: # (- Create a new page in the features directory)

[//]: # (- Use Detection mixin for common functionalities)

[//]: # (- Navigation:)

[//]: # (  - Add new path to router.dart)

[//]: # (  - Add new navigation buttons to each screen &#40;for development/testing purposes&#41;)

