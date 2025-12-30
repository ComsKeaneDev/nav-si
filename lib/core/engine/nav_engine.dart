import 'dart:async';
import 'package:camera/camera.dart';
import '../services/camera_manager.dart';
import '../architecture/nav_extension.dart';


class NavEngine {
  final CameraManager _cameraManager;
  final List<NavExtension> _activeExtensions = [];

  // switch, avoiding process data
  bool _isRunning = false;
  NavEngine(this._cameraManager);

  // get active extension
  List<NavExtension> get activeExtensions => _activeExtensions;

  // initial engine
  Future<void> initialize() async {
    await _cameraManager.initialise();
    await _cameraManager.startStreaming();

    // listen camera stream
    _cameraManager.frameStream.listen((frame) {
      if (_isRunning && _activeExtensions.isNotEmpty) {
        _distributeFrame(frame);
      }
    });
  }

  // pass the frame to all active extension
  void _distributeFrame(CameraImage frame) {
    // parallel
    for (var ext in _activeExtensions) {
      ext.processFrame(frame);
    }
  }

  /// Core Functionality allows user switch to different extensions
  Future<void> switchMode(List<NavExtension> newExtensions) async {
    _isRunning = false;

    // stop old extensions
    for (var ext in _activeExtensions) {
      await ext.stop();
      print("Engine: Stopped ${ext.name}");
    }
    _activeExtensions.clear();

    // start new extensions
    for (var ext in newExtensions) {
      await ext.initial();
      _activeExtensions.add(ext);
      print("Engine: Started ${ext.name}");
    }

    _isRunning = true;
  }

  void dispose() {
    _isRunning = false;
    for (var ext in _activeExtensions) {
      ext.stop();
    }
    _cameraManager.dispose();
  }
}




