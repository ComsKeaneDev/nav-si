import 'dart:async';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';


/// manage the camera
/// initial the camera hardware, send each frame as a Stream
class CameraManager {
  CameraController? _controller;
  CameraController? get controller => _controller;

  final StreamController<CameraImage> _frameStreamController = StreamController<CameraImage>.broadcast();
  /// this is the new architecture that allow further implementation
  /// cause YOLO before only access phone camera, this allows different kinds of "camera" being used
  /// as this only care about the Stream instead of hardware
  Stream<CameraImage> get frameStream => _frameStreamController.stream;

  // initial camera
  Future<void> initialise() async {
    // initialise controller
    await Permission.camera.request().isGranted;    // return bool value to show have permission
    // initialise camera
    final cameras = await availableCameras();
    _controller = CameraController(cameras[0], ResolutionPreset.medium);

    await _controller!.initialize();
  }

  // push frame into stream
  Future<void> startStreaming() async {
    await _controller!.startImageStream((CameraImage image) {
      _frameStreamController.add(image);
    });
  }

  // stop streaming
  Future<void> stopStreaming() async {
    await _controller!.stopImageStream();
  }

  // dispose
  void dispose() {
    stopStreaming();
    _controller?.dispose();
    _frameStreamController.close();
  }
}