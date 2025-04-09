import 'dart:io';
import 'package:image/image.dart' as img;
import '../utils/pixel_utils.dart';
import 'scanner_config.dart';

// Load the image from the file and decode it into an Image object
Future<img.Image> loadImage(File file) async {
  final bytes = await file.readAsBytes();
  return img.decodeImage(bytes)!;
}

// Get the average brightness of the pixels in a specific bubble area
int getAverageBrightness(img.Image image, int x, int y) {
  int total = 0;
  int count = bubbleWidth * bubbleHeight;

  for (int dx = 0; dx < bubbleWidth; dx++) {
    for (int dy = 0; dy < bubbleHeight; dy++) {
      final pixel = image.getPixel(x + dx, y + dy);
      final gray = ((pixel.r + pixel.g + pixel.b) ~/ 3);
      total += gray;
    }
  }

  return total ~/ count;
}

// Extract the answers from the bubble sheet based on the detected brightness
Future<Map<int, String>> extractAnswers(File imageFile) async {
  final image = await loadImage(imageFile);
  Map<int, String> result = {};

  for (int q = 0; q < 60; q++) {
    int rowY = startY + (q * rowSpacing);
    List<int> brightness = [];

    for (int opt = 0; opt < 4; opt++) {
      int x = startX + (opt * colSpacing);
      int avg = getAverageBrightness(image, x, rowY);
      brightness.add(avg);
    }

    result[q + 1] = getFilledBubble(brightness);
  }

  return result;
}
