import 'package:flutter/material.dart';
import 'bubble_config.dart';

class BubbleOverlayPainter extends CustomPainter {
  final List<Map<String, double>> bubbles;
  final Set<int>? filledBubbleIndices; // indices (or could be coordinates)

  BubbleOverlayPainter(this.bubbles, {this.filledBubbleIndices});
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < bubbles.length; i++) {
      final bubble = bubbles[i];
      final isFilled = filledBubbleIndices != null && filledBubbleIndices!.contains(i);
      final paint = Paint()
        ..color = isFilled ? Colors.green : Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(
        Offset(bubble['x']!, bubble['y']!),
        bubble['r']!,
        paint,
      );
    }
  
    final borderPaint = Paint()
      ..color = Colors.red.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;



    final textPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    const guideRatio = 3 / 4;
    double guideWidth = size.width * 0.9;
    double guideHeight = guideWidth / guideRatio;

    if (guideHeight > size.height * 0.85) {
      guideHeight = size.height * 0.85;
      guideWidth = guideHeight * guideRatio;
    }

    final guideTopLeft = Offset(
      (size.width - guideWidth) / 2,
      (size.height - guideHeight) / 2,
    );



    double scaleX = guideWidth / 1080;
    double scaleY = guideHeight / 1920;

    for (int col = 0; col < 3; col++) {
      for (int q = 0; q < questionsPerColumn; q++) {
        int questionNumber = col * questionsPerColumn + q + 1;
        double rowY = guideTopLeft.dy + (startY + q * rowSpacing) * scaleY;
        double colX = guideTopLeft.dx + (startX + col * columnSpacing) * scaleX;

        for (int opt = 0; opt < 4; opt++) {
          double x = colX + opt * colSpacing * scaleX;

          canvas.drawRect(
            Rect.fromLTWH(
              x,
              rowY,
              bubbleWidth * scaleX,
              bubbleHeight * scaleY,
            ),
            borderPaint,
          );

          if (q == 0) {
            textPaint.text = TextSpan(
              text: String.fromCharCode(65 + opt),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12 * scaleX,
                fontWeight: FontWeight.bold,
              ),
            );
            textPaint.layout();
            textPaint.paint(
              canvas,
              Offset(
                x + (bubbleWidth * scaleX - textPaint.width) / 2,
                rowY - 20 * scaleY,
              ),
            );
          }
        }

        textPaint.text = TextSpan(
          text: '$questionNumber',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12 * scaleX,
            fontWeight: FontWeight.bold,
          ),
        );
        textPaint.layout();
        textPaint.paint(
          canvas,
          Offset(
            colX - 25 * scaleX,
            rowY + (bubbleHeight * scaleY - textPaint.height) / 2,
          ),
        );
      }
    }
  }

  @override
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
