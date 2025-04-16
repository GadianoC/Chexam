import 'dart:io';
import 'dart:math' show pi, cos, sin;
import 'package:image/image.dart' as img;
import 'scanner_config.dart';

// Load the image from the file and decode it into an Image object
Future<img.Image> loadImage(File file) async {
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Failed to decode image.');
  return decoded;
}

// Get the average brightness of the pixels in a specific bubble area
int getAverageBrightness(img.Image image, int x, int y) {
  List<int> brightnessList = [];
  int darkPixelCount = 0;
  const darkThreshold = 128; // Lower threshold for better detection

  final centerX = x + (bubbleWidth ~/ 2);
  final centerY = y + (bubbleHeight ~/ 2);
  final radius = (bubbleWidth ~/ 2).toDouble();

  // Sample pixels in a circular pattern
  for (double angle = 0; angle < 360; angle += 5) {
    for (double r = 0; r <= radius; r += 1) {
      final px = (centerX + r * cos(angle * pi / 180)).toInt();
      final py = (centerY + r * sin(angle * pi / 180)).toInt();

      if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
        final pixel = image.getPixel(px, py);
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
        brightnessList.add(gray);

        if (gray < darkThreshold) {
          final weight = 1.0 - (r / radius);
          darkPixelCount += (weight * 2).toInt();
        }
      }
    }
  }

  if (brightnessList.isEmpty) return 255;

  brightnessList.sort();
  final medianBrightness = brightnessList[brightnessList.length ~/ 2];
  final darkPixelPercentage = darkPixelCount / (brightnessList.length);

  // More aggressive dark pixel detection
  return (darkPixelPercentage > 0.25)
      ? (medianBrightness ~/ 2)
      : medianBrightness;
}

String getFilledBubble(List<int> brightness) {
  if (brightness.length != 4) return '';

  // Find the two darkest bubbles
  List<MapEntry<int, int>> indexed = List.generate(
    brightness.length,
    (i) => MapEntry(i, brightness[i]),
  );
  indexed.sort((a, b) => a.value.compareTo(b.value));

  // If there's a clear darkest bubble (significantly darker than the second darkest)
  if (indexed[0].value < indexed[1].value * 0.8) {
    return ['A', 'B', 'C', 'D'][indexed[0].key];
  }

  // If the two darkest bubbles are too similar, consider it ambiguous
  return '';
}

Future<Map<int, String>> extractAnswers(File imageFile) async {
  final image = await loadImage(imageFile);
  final result = <int, String>{};

  for (int col = 0; col < 3; col++) {
    for (int q = 0; q < questionsPerColumn; q++) {
      final questionNumber = col * questionsPerColumn + q + 1;
      final rowY = startY.toInt() + (q * rowSpacing).toInt();
      final colX = startX.toInt() + (col * columnSpacing).toInt();
      final brightness = <int>[];

      for (int opt = 0; opt < 4; opt++) {
        final x = colX + (opt * colSpacing).toInt();
        final avg = getAverageBrightness(image, x, rowY);
        brightness.add(avg);
      }

      final answer = getFilledBubble(brightness);
      if (answer.isNotEmpty) {
        result[questionNumber] = answer;
      }
    }
  }

  return result;
}

// For debugging: Visualize bubble positions and detected answers
Future<void> visualizeBubblePositions(File inputFile, String outputPath) async {
  final image = await loadImage(inputFile);
  final red = img.ColorRgb8(255, 0, 0);
  final green = img.ColorRgb8(0, 255, 0);

  for (int col = 0; col < 3; col++) {
    for (int q = 0; q < questionsPerColumn; q++) {
      final rowY = startY.toInt() + (q * rowSpacing).toInt();
      final colX = startX.toInt() + (col * columnSpacing).toInt();
      final brightness = <int>[];

      for (int opt = 0; opt < 4; opt++) {
        final x = colX + (opt * colSpacing).toInt();
        final avg = getAverageBrightness(image, x, rowY);
        brightness.add(avg);

        // Draw bubble rectangles
        img.drawRect(
          image,
          x1: x,
          y1: rowY,
          x2: x + bubbleWidth.toInt(),
          y2: rowY + bubbleHeight.toInt(),
          color: red,
          thickness: 2,
        );
      }

      final answer = getFilledBubble(brightness);
      if (answer.isNotEmpty) {
        final opt = answer.codeUnitAt(0) - 'A'.codeUnitAt(0);
        final x = colX + (opt * colSpacing).toInt();
        
        // Highlight detected answer
        img.drawRect(
          image,
          x1: x - 2,
          y1: rowY - 2,
          x2: x + bubbleWidth.toInt() + 2,
          y2: rowY + bubbleHeight.toInt() + 2,
          color: green,
          thickness: 2,
        );
      }
    }
  }

  await File(outputPath).writeAsBytes(img.encodeJpg(image));
}
