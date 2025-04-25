import 'package:flutter/material.dart';

/// Paints overlay circles over detected bubble centers for debugging.
class BubbleOverlayPainter extends CustomPainter {
  final List<Map<String, double>> detectedBubbles;
  final double imageWidth;
  final double imageHeight;

  BubbleOverlayPainter({
    required this.detectedBubbles,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    for (final bubble in detectedBubbles) {
  if (bubble.containsKey('centerX') && bubble.containsKey('centerY')) {
    final cx = bubble['centerX'] ?? 0.0;
    final cy = bubble['centerY'] ?? 0.0;
    final dx = cx * size.width / imageWidth;
    final dy = cy * size.height / imageHeight;
    canvas.drawCircle(Offset(dx, dy), 16, paint);
  }
}
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
