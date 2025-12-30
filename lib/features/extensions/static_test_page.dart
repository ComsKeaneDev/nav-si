import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';

class StaticTestPage extends StatefulWidget {
  const StaticTestPage({super.key});

  @override
  State<StaticTestPage> createState() => _StaticTestPageState();
}

class _StaticTestPageState extends State<StaticTestPage> {
  late FlutterVision vision;
  bool isLoaded = false;

  // 存储图片数据用于显示
  ui.Image? _image;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    vision = FlutterVision();
    // 1. 加载模型 (请确保路径和你之前的一样)
    await vision.loadYoloModel(
      modelPath: 'assets/models/yolo11n.tflite', // 或者 yolov8n.tflite
      labels: 'assets/models/labels.txt',
      modelVersion: "yolo11", // 如果用 v8 模型，记得改回 "yolov8"
      quantization: false,
      numThreads: 1,
      useGpu: false,
    );
    setState(() {
      isLoaded = true;
    });

    // 2. 模型加载完后，自动开始测试
    _runInference();
  }

  Future<void> _runInference() async {
    // A. 读取 Assets 中的图片
    final ByteData byteData = await rootBundle.load('assets/test.jpg');
    final Uint8List imageBytes = byteData.buffer.asUint8List();

    // B. 获取图片宽高 (用于传参和画框比例计算)
    final ui.Image image = await decodeImageFromList(imageBytes);

    // C. 运行 YOLO (注意这里用的是 yoloOnImage)
    final results = await vision.yoloOnImage(
      bytesList: imageBytes,
      imageHeight: image.height,
      imageWidth: image.width,
      iouThreshold: 0.45,
      confThreshold: 0.50, // 50% 以上才显示
      classThreshold: 0.50,
    );

    if (mounted) {
      setState(() {
        _image = image;
        _results = results;
      });
    }
  }

  @override
  void dispose() {
    vision.closeYoloModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded || _image == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Static Image Debug")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 使用 CustomPaint 绘制图片和框
              FittedBox(
                child: SizedBox(
                  width: _image!.width.toDouble(),
                  height: _image!.height.toDouble(),
                  child: CustomPaint(
                    painter: ImageBoxPainter(
                      image: _image!,
                      results: _results,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _runInference,
                  child: const Text("Run Again")
              ),
              const SizedBox(height: 20),
              // 显示原始数据方便调试
              Text("Results count: ${_results.length}"),
            ],
          ),
        ),
      ),
    );
  }
}

// === 专用的静态图片画笔 ===
class ImageBoxPainter extends CustomPainter {
  final ui.Image image;
  final List<Map<String, dynamic>> results;

  ImageBoxPainter({required this.image, required this.results});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 先把图片画上去
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: image,
      fit: BoxFit.fill,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 // 线粗一点
      ..color = Colors.red;

    final textStyle = TextStyle(
      color: Colors.white,
      backgroundColor: Colors.black,
      fontSize: 30, // 字体大一点
      fontWeight: FontWeight.bold,
    );

    for (var result in results) {
      final box = result["box"];
      // yoloOnImage 返回的坐标通常是基于原图像素的，不需要复杂的比例转换
      // 格式通常是 [x1, y1, x2, y2, conf]
      double x1 = box[0].toDouble();
      double y1 = box[1].toDouble();
      double x2 = box[2].toDouble();
      double y2 = box[3].toDouble();

      // 绘制矩形
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), paint);

      // 绘制标签
      final textSpan = TextSpan(
        text: "${result['tag']} ${(box[4] * 100).toStringAsFixed(0)}%",
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x1, y1 - 40));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}