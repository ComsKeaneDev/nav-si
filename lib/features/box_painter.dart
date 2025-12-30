import 'package:flutter/material.dart';
import 'dart:io';

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> results;
  final Size previewSize;
  final Size screenSize;

  BoundingBoxPainter({
    required this.results,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final textStyle = TextStyle(
      color: Colors.black,
      backgroundColor: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    for (var result in results) {
      // 1. 获取坐标 [x1, y1, x2, y2, conf]
      final box = result["box"];
      double x1 = box[0];
      double y1 = box[1];
      double x2 = box[2];
      double y2 = box[3];

      // 2. 计算缩放比例 (这是最难的一步)
      // Android 上通常：预览图的"宽"对应屏幕的"高"，预览图的"高"对应屏幕的"宽"
      double scaleX, scaleY;

      if (Platform.isAndroid) {
        // 交叉对应：屏幕宽 / 预览高
        scaleX = screenSize.width / previewSize.height;
        scaleY = screenSize.height / previewSize.width;
      } else {
        // iOS 通常不需要交叉
        scaleX = screenSize.width / previewSize.width;
        scaleY = screenSize.height / previewSize.height;
      }

      // 3. 应用缩放
      // 注意：flutter_vision 有时返回的坐标需要根据镜像调整，这里先写标准逻辑
      final rect = Rect.fromLTRB(
        x1 * scaleX,
        y1 * scaleY,
        x2 * scaleX,
        y2 * scaleY,
      );

      // 4. 画框
      canvas.drawRect(rect, paint);

      // 5. 画标签文字
      final textSpan = TextSpan(
        text: "${result['tag']} ${(box[4] * 100).toStringAsFixed(0)}%",
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}