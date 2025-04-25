import 'dart:io';
import 'dart:math' show pi, cos, sin;
import 'package:image/image.dart' as img;
import 'bubble_config.dart';

// Load the image from the file and decode it into an Image object
Future<img.Image> loadImage(File file) async {
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Failed to decode image.');
  return decoded;
}

// Get the average brightness of the pixels in a specific bubble area
// Get the minimum brightness of the pixels in a specific bubble area, and print debug info
int getAverageBrightness(img.Image image, int x, int y) {
  List<int> brightnessList = [];
  int darkPixelCount = 0;
  const darkThreshold = 180; // More sensitive to shading

  final centerX = x + (bubbleWidth ~/ 2);
  final centerY = y + (bubbleHeight ~/ 2);
  final radius = (bubbleWidth ~/ 2).toDouble() * 0.6; // Sample only 60% of the bubble radius
  print('[DEBUG] Sampling bubble at x=$x, y=$y, center=($centerX,$centerY), r=$radius');

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
          darkPixelCount++;
        }
      }
    }
  }

  if (brightnessList.isEmpty) return 255;

  brightnessList.sort();
  final percentileIndex = (brightnessList.length * 0.1).toInt().clamp(0, brightnessList.length - 1);
  final darkValue = brightnessList[percentileIndex];
  final medianBrightness = brightnessList[brightnessList.length ~/ 2];
  final darkPixelPercentage = darkPixelCount / (brightnessList.length);

  print('[DEBUG] Bubble at ($x, $y): 10th%=$darkValue, median=$medianBrightness, dark%=$darkPixelPercentage');
  return darkValue;
}

// Only select an answer if the darkest bubble is at least 30 less than the next darkest, otherwise leave blank
String getFilledBubble(List<int> brightness) {
  int minValue = brightness.reduce((a, b) => a < b ? a : b);
  int minIndex = brightness.indexOf(minValue);
  // Find the next darkest value
  List<int> sorted = List.from(brightness)..sort();
  int nextDarkest = sorted.length > 1 ? sorted[1] : 255;
  // Only return answer if it's much darker than the next
  if (minValue < 200 && (nextDarkest - minValue) >= 30) {
    return String.fromCharCode(65 + minIndex);
  }
  // If the two darkest bubbles are too similar, consider it ambiguous
  return '';
}

Future<Map<int, String>> extractAnswers(File imageFile) async {
  print('[DEBUG] Analysis image file: \x1b[36m${imageFile.path}\x1b[0m');
  final imgBytes = await imageFile.readAsBytes();
  final imgDecoded = img.decodeImage(imgBytes);
  if (imgDecoded != null) {
    print('[DEBUG] Analysis image size: \x1b[36m${imgDecoded.width}x${imgDecoded.height}\x1b[0m');
  }
  final image = await loadImage(imageFile);
  final result = <int, String>{};

  // Process all columns and questions (3 columns x 20 questions)
  const int numColumns = 3;
  for (int col = 0; col < numColumns; col++) {
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

      // Print all candidate brightnesses for this question
      for (int i = 0; i < brightness.length; i++) {
        print('[DEBUG] Q$questionNumber option ${String.fromCharCode(65 + i)}: brightness=${brightness[i]}');
      }
      final answer = getFilledBubble(brightness);
      print('[DEBUG] Q$questionNumber brightness: $brightness => $answer');
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
