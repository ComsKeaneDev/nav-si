# NAV-SI: Navigation And Visio-Spatial Information

## Overview

- NAV-SI is an AI-based, multimodal, mobile application to enhance navigation and situational awareness for (particularly blind or visually impaired) users. NAV-SI is free and open-source; and runs in real-time, on-device, with an accessible UI.
- Current extensions (with the ability to detect everything in surroundings or to specify a detection target):
    - object detection - positional & color information
    - text detection - positional information (for specific target text only)

[//]: # ()
[//]: # (# Initial Project Structure Proposal)

[//]: # ()
[//]: # (```text)

[//]: # (lib/)

[//]: # (├── core/)

[//]: # (│   ├── services/)

[//]: # (│   ├── orchestrator/)

[//]: # (│   └── models/)

[//]: # (│)

[//]: # (├── features/)

[//]: # (│   ├── face_recognition/)

[//]: # (│   ├── object_detection/)

[//]: # (│   └── ocr/)

[//]: # (│)

[//]: # (├── state/)

[//]: # (│)

[//]: # (└── ui/)

[//]: # (```)

[//]: # ()
[//]: # (-   **core/**  )

[//]: # (    Shared utilities: camera, audio, ML engine abstractions; the “brain” that wires tasks together; and simple DTOs.)
[//]: # ()
[//]: # (    )
[//]: # (-   **features/**  )

[//]: # ()
[//]: # (    One sub-folder per model feature &#40;that’s where the code lives to detect, embed, classify, store, etc.&#41;)

[//]: # ()
[//]: # (    )
[//]: # (-   **state/**  )

[//]: # ()
[//]: # (    The state management layer &#40;BLoC/Provider/Riverpod ??&#41; that sits between the orchestrator and anything that “listens” &#40;UI, headphones, haptics&#41;.)

[//]: # ()
[//]: # (    )
[//]: # (-   **ui/**  )

[//]: # ()
[//]: # (    Screens and widgets. In the future this will be minimal but right now it holds Flutter views.)

[//]: # ()
[//]: # ()
[//]: # (##  core/)

[//]: # ()
[//]: # (### services/)

[//]: # ()
[//]: # (Low-level wrappers around platform APIs. )

[//]: # ()
[//]: # (- ##### Camera service)

[//]: # ()
[//]: # (  - Camera services that expose a single stream of input frames)

[//]: # ()
[//]: # (  - Handles permission requests, camera resolution setups, and image format conversions)

[//]: # ()
[//]: # (- #### Audio service)

[//]: # ()
[//]: # (  - Manages voice input from headphones &#40;or taps from AirPods&#41;)

[//]: # ()
[//]: # (  - Sends a stream of voice data )

[//]: # ()
[//]: # (- #### Model engine)

[//]: # ()
[//]: # (  - Manages loading of models in TFlite, CoreML, or other formats ?)

[//]: # ()
[//]: # (  - Should provide an async/future runModel API so each feature doesn't need to handle the model format)

[//]: # ()
[//]: # ()
[//]: # (### orchestrator/)

[//]: # ()
[//]: # (Coordinates which “tasks” are active, passes camera frames & voice commands, and fetches results.)

[//]: # ()
[//]: # (- #### Producer)

[//]: # ()
[//]: # (  - Registers services and factories for each task &#40;if identify face instantiate a face recognition task handler&#41;)

[//]: # ()
[//]: # (- #### Orchestrator)

[//]: # ()
[//]: # (  - Holds a list of all implemented tasks &#40;with associated IDs&#41;)

[//]: # ()
[//]: # (    task_orchestrator.dart)

[//]: # ()
[//]: # (  - Listens for frames and voice commands. When a "change task to x" command arrives, it initialises tasks[x]. On each frame, a task.run&#40;frame&#41; is called &#40;could even be multiple tasks. e.g. identification/face recognition could always be running in certain scenarios&#41;)

[//]: # ()
[//]: # (  - Should expose a stream of results to which some consumer can subscribe &#40;e.g. a consumer listening for familiar faces needs to know when a familiar face appears and then go through some notification logic&#41;)

[//]: # ()
[//]: # (### models/)

[//]: # ()
[//]: # (Data objects shared across the app.)

[//]: # ()
[//]: # (- #### Task result)

[//]: # ()
[//]: # (  - Base class for results.)

[//]: # ()
[//]: # (  - Subclasses like FaceResult &#40;contains name, confidence, boundingBox&#41;, OcrResult, etc.)

[//]: # ()
[//]: # ()
[//]: # ()
[//]: # (## features/)

[//]: # ()
[//]: # (Each feature folder implements exactly one Task. e.g.)

[//]: # ()
[//]: # (```text)

[//]: # ()
[//]: # (features/)

[//]: # ()
[//]: # (└── face_recognition/)

[//]: # ()
[//]: # (    ├── face_task.dart)

[//]: # ()
[//]: # (    ├── face_detector.dart)

[//]: # ()
[//]: # (    ├── face_embedder.dart)

[//]: # ()
[//]: # (    └── face_search.dart)

[//]: # ()
[//]: # (```)

[//]: # ()
[//]: # (- Implements a shared Task interface.)

[//]: # ()
[//]: # (- Coordinates subcomponents &#40;e.g. detector → embedder → vector search&#41;)

[//]: # ()
[//]: # ()
[//]: # (## state/)

[//]: # ()
[//]: # (Connects the UI/events layer with the processing backend. Need to figure out what the best way to manage states is &#40;options seem to be BLoC/Provider/Riverpod&#41;. )

[//]: # ()
[//]: # ()
[//]: # (## ui/)

[//]: # ()
[//]: # (Contains any UI widgets that we make during testing. The final UI is going to change over time, but users should mostly rely on voice control.)

[//]: # ()
[//]: # ()
[//]: # (## misc/ )

[//]: # ()
[//]: # (The stuff that was already there &#40;YOLO demo and the websocket testing&#41;)

## Project Architecture

```text
lib/
├── core/
│   ├── services/
│   ├── orchestrator/
│   └── models/
│
├── extensions/
│
├── state/
│
└── ui/
```

- **core/**
    - models/: ML models (YOLO)
    - orchestrator/:
    - services/:
        - audio/: handles microphones, text-to-speech (speaker), speech-to-text
        - camera/: handles camera sources (mobile and hardware)
        - media_manager.dart: manages all media sources for extensions

- **extensions/**
    - detection/: holds object & text detection extensions + utility functions and settings

- **state/**
    - router.dart - provides routing between tasks with Riverpod
  
- **ui/**
  - widgets/: widgets for pages (buttons, etc.)

## Tech Stack

NAV-SI is built in Flutter with the Dart programming language.

### Models

#### Object Detection:
- [Ultralytics YOLO 11n](https://docs.ultralytics.com/models/yolo11/) (loaded as Tensorflow Lite for Android & coreML for iOS)

#### Text Detection:
- [Google's ML Kit Text Recognition](https://pub.dev/packages/google_mlkit_text_recognition)

#### Text-to-Speech (TTS):
- [flutter_tts](https://pub.dev/packages/flutter_tts) package

#### Speech-to-Text (ASR):
- [sherpa_onnx](https://pub.dev/packages/sherpa_onnx) package
- Model: sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06

### Hardware

#### Camera Unit

Overview:
- Camera: [XIAO ESP32-S3 Sense](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/) (Version 0.7.0)
  - Resolution: 640x480
- Microphone: mounted digital microphone
- Battery: PKCELL LP503562 3.7V 1200mAH
  - To charge: attach camera to battery & plug camera into power source
  - Time to full charge:
  - Time full charge lasts: ~4 hours (no devices connected)
- Connection cable: USB-C

Red light indicator (unable to fully verify):
- Without battery: red light comes on for 30 seconds when camera is plugged into power source
- With battery: red light flashes when camera is plugged into power source for charging battery & turns off when battery is fully charged

To use with app:
- Attach camera to battery or plug into power source
- Connect phone to camera's wifi hotspot (& turn of mobile data): ID = WearableCam, password = 12345678 (maximum of 4 devices connected)
  - Ensure camera is close enough to PC/phone
- Run app

To test:
- Attach camera to battery or plug into power source
- Connect PC/phone (turn off mobile data) to camera's wifi hotspot: ID = WearableCam, password = 12345678 (maximum of 4 devices)
  - Ensure camera is close enough to PC/phone
- Navigate to static IP address 192.168.4.1:
  - http://192.168.4.1:80/stream - live video stream (~20 FPS)
  - http://192.168.4.1:80/audio - live audio recording in browser (WAV)
  - http://192.168.4.1:80/audio_raw - audio recording download (PCM)

#### Glasses

[Glasses comparison](https://docs.google.com/spreadsheets/d/1NHf96gup78AlJRGht3S0XKKXMw83qJYMeD81AcZA0-E/edit?usp=sharing) (restricted access)

## Voice Control

NAV-SI works entirely through voice control.
Below are the steps and commands to follow (each ⟶ arrow indicates the verbal confirmation message after a prompt is given).

To give each voice prompt below:
- To start recording: press the mic button ⟶ _"On" & button in activated state
- To stop recording: press the mic button again & button in deactivated state

### Setting Commands:
- To switch tasks: "Switch to [object/text] detection" ⟶ _"[object/text] detection extension"_
- To turn position/color (only for object detection) information on/off: "Settings [position/color] on" → _"[Positional/Color] on"_
    - Default: positional information on, color information off
- To turn search or position/color (only for object detection) information off: "Settings [search/position/color] off" → _"[Search/Positional/Color] off"_
- To receive a report on current search settings (extension name, position/color information, current target): "Settings report"
  ⟶ _"Settings: [object/text] detection extension, search: [on/off], (if search on: position: [on/off], [color: [on/off]], searching for: ...)"_

### Updating Search:
- Object detection: give a phrase containing the target object(s) or the words "all objects"
    - "I'm searching for my laptop and keys" ⟶ _"Searching for: laptop, keys"_
    - "Announce all objects around me" ⟶ _"Searching for all objects"_
- Text detection: give the exact target text or say "all text"
    - "stairs" ⟶ _"Searching for: stairs"_
    - "all text" ⟶ _"Searching for all text"_

### Troubleshooting:
- If your voice isn't being recognized, try to...
    - Wait a moment longer after pressing the button before speaking, and wait a moment longer after speaking before pressing the button again
    - Speak loudly and close to the microphone
    - Speak clearly/enunciate your words
- If the 'Record' button isn't responding when pressed (no 'On' verification)...
    * this sometimes happens when speaking is in progress
    - Try to press again
    - Cover the camera with your hand so all speaking stops & try again

## Demos

To give voice command (for all prompting steps below): 
- To start recording: press mic button in lower right corner ⟶ "On" & mic icon switches to filled in/solid version with darker background color
- To stop recording: press button again ⟶ mic icon switches to outlined version with lighter background color

### Object Detection
- Open app ⟶ _"Object detection extension"_  

**All objects**

- Say "Please announce all objects" ⟶ _"Searching for all objects"_
- Pan camera around ⟶ _e.g. "Found: laptop near center, found: backpack near lower right"_  

**Target objects**

- Say "I'm looking for a chair or bench to rest at" ⟶ _"Searching for: chair, bench"_
- Pan camera to find chairs ⟶ _e.g. "Found: chair near lower left edge, found: chair near center"_  

**Color detection**

- Say "Settings color on" ⟶ _"Color on"_
- Pan camera to find chairs ⟶ _e.g. "Found: black chair near lower left edge, found: red chair near center"_

### Text Detection
- Open app ⟶ _"Object detection extension"_
- Say "Switch to text detection" ⟶ _"Text detection extension"_

**All text**

- Say "All text" ⟶ _"Searching for all text"_
- Pan camera to find text ⟶ _e.g. "In case of fire, use stairs"_  

**Target text**

- Say "toilet" ⟶ _"Searching for: toilet"_
- Pan camera to find text ⟶ _e.g. "Found: toilet near upper edge"_

### Settings
- Open app ⟶ _"Object detection extension"_
- Say "Settings report" ⟶ _"Settings: object detection extension, search: off"_
- Say "Is there a person near me?" ⟶ _"Searching for: person"_
- Say "Settings report" ⟶ _"Settings: object detection extension, search: on, position: on, color: off, searching for: person"_
- Say "Settings color on" ⟶ _"Color on"_
- Say "Settings report" ⟶ _"Settings: object detection extension, search: on, position: on, color: on, searching for: person"_
- Say "Settings search off" ⟶ _"Search off"_
- Say "Settings report" ⟶ _"Settings: object detection extension, search: off"_

## Next Steps
- New app architecture - see [New App Architecture (2026)](#new-app-architecture-2026)
  - Add new extensions - see [Modes](#modes)
  - Develop frontend/UI - see [UI](#ui)
- Implement backend for saved user accounts
- Add LLM layer between voice prompting & state updates
    - Takes in prompt and returns all the possible prompts/commands
    - LLM for function calling: [Function Gemma (Google)](https://www.perplexity.ai/page/google-releases-functiongemma-RgbvJXGXSPGdaXvJKjnsaw)
- Switch to entirely contactless
    - Remove all button UI elements?
    - Add wake-word detection ("Hey Siri," "OK Google," etc.)
    - Use AirPods/wireless earbuds (include microphone, button support)
- Test with iOS (currently only tested with Android)
- User testing - see [User Testing](#user-testing)
- *To extend upon app: add capability or prebuilt mode with all capabilities & parameters set!!

## New App Architecture (2026)

### Requirements

#### Objectives
- NAV-SI is an AI-based, multimodal, mobile application to enhance navigation and situational awareness for blind and visually impaired users
- NAV-SI is free and open-source
- NAV-SI runs in real time, on-device, with an accessible UI
  - Voice-control
  - [Flutter accessibility resources](https://docs.flutter.dev/ui/accessibility) & [Guide to Flutter accessibility](https://karol-wrotniak.medium.com/a-practical-guide-to-flutter-accessibility-part-1-the-basics-98f553be00bc) - Semantics widgets, screen reader testing, etc.

- NAV-SI has a modular, extensible framework with a reliable, core infrastructure that contributors can build on top of for decades to come

#### Collaboration
- New contributions can easily be built on top of existing functionality/features (extension built upon an extension of an extension), including parallel work on separate modules
- There exists thorough and transparent documentation about each data stream that can be subscribed to and built off of, including:
    - Licensing
    - Attribution
    - Technical spec/performance - data types, FPS, blocking loop vs. non-blocking loop, etc.
    - Dependencies/requirements
- There exists a clear ability to track each developer’s contributions

#### Loop Management
- There exists ability to easily switch between camera/audio feeds and modes with app running optimally for current parameters
    - No bottlenecks due to performance of inactive feeds/modes

### Modes

[Detailed mode notes](docs/modes.md)

### UI

[Detailed UI notes](docs/ui.md)

## User Testing

[NAV-SI demos timeline](https://docs.google.com/document/d/1sI3XRobVcRf40LUmOM32NisUZ1gzA16Otf7W6YgggCg/edit?usp=sharing) (restricted access)

## Misc

### Sending Object Detection Data:
- To turn JSON data sending on/off: update bool sendData in object_detection.dart
- To update IP address: change at "change IP address here" in object_detection.dart

### Other Apps

[Comparison of other apps](https://docs.google.com/spreadsheets/d/1a-yV3-vZRpIx8hxUx_fP6JEdI-Cq5HiHh1Dgg-SlcZA/edit?usp=sharing) (restricted access)