import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:image/image.dart' as img;

class WebSocketYoloDemo extends StatefulWidget {
  @override
  _WebSocketYoloDemoState createState() => _WebSocketYoloDemoState();
}

class _WebSocketYoloDemoState extends State<WebSocketYoloDemo> {
  late YOLOViewController controller;
  late WebSocketChannel channel;
  final int modelW = 640, modelH = 640;
  List<YoloResult> latestResults = [];
  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    controller = YOLOViewController(
      modelPath: 'assets/yolo11n.tflite',
      task: YOLOTask.detect,
    );
    channel = WebSocketChannel.connect(
      Uri.parse('ws://yourserver.example.com:8080'),
    );
    _socketSub = channel.stream.listen(_onFrameBytes);
  }

  Future<void> _onFrameBytes(dynamic data) async {
    if (data is Uint8List) {
      // 1. Decode JPEG→RGB bytes:
      final ui.Codec codec = await ui.instantiateImageCodec(data);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image uiImage = frameInfo.image;
      final ByteData? byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final Uint8List rgba = byteData!.buffer.asUint8List();

      // 2. Convert RGBA→RGB:
      final int origW = uiImage.width, origH = uiImage.height;
      final Uint8List rgb = Uint8List(origW * origH * 3);
      for (int i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
        rgb[j] = rgba[i];
        rgb[j + 1] = rgba[i + 1];
        rgb[j + 2] = rgba[i + 2];
      }

      // 3. Resize to 640×640 (model input):
      final img.Image origImage = img.Image.fromBytes(
        width: origW,
        height: origH,
        bytes: rgb,
        order: img.ChannelOrder.rgb,
      );
      final img.Image resizedImage = img.copyResize(
        origImage,
        width: modelW,
        height: modelH,
      );
      final Uint8List modelInputBytes = Uint8List.fromList(
        resizedImage.getBytes(order: img.ChannelOrder.rgb),
      );

      // 4. Run inference:
      final List<YoloResult> results = await controller.detectImage(
        modelInputBytes,
        modelW,
        modelH,
      );

      // 5. Update UI with results:
      setState(() {
        latestResults = results;
      });
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    channel.sink.close();
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // You can show the results on a CustomPainter overlay.
      body: CustomPaint(
        painter: _YoloPainter(latestResults),
        child: Center(child: Text('WebSocket YOLO Demo')),
      ),
    );
  }
}

class _YoloPainter extends CustomPainter {
  final List<YoloResult> results;
  _YoloPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final r in results) {
      final rect = Rect.fromLTWH(
        r.x * size.width,
        r.y * size.height,
        r.width * size.width,
        r.height * size.height,
      );
      canvas.drawRect(rect, paint);
      final textSpan = TextSpan(
        text: '${r.className} ${(r.confidence * 100).toStringAsFixed(1)}%',
        style: TextStyle(color: Colors.red, fontSize: 14),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset(rect.left, rect.top - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _YoloPainter old) => true;
}
