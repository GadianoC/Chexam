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
  List<int> brightnessList = [];
  int darkPixelCount = 0;
  const darkThreshold = 128; // Threshold for considering a pixel as dark

  for (int dx = 0; dx < bubbleWidth; dx++) {
    for (int dy = 0; dy < bubbleHeight; dy++) {
      int px = x + dx;
      int py = y + dy;

      // Only sample if within bounds
      if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
        final pixel = image.getPixel(px, py);
        final gray = ((pixel.r + pixel.g + pixel.b) ~/ 3);
        brightnessList.add(gray);
        
        if (gray < darkThreshold) {
          darkPixelCount++;
        }
      }
    }
  }

  if (brightnessList.isEmpty) return 255;

  // Sort brightness values to get median
  brightnessList.sort();
  int medianBrightness = brightnessList[brightnessList.length ~/ 2];

  // Calculate percentage of dark pixels
  double darkPixelPercentage = darkPixelCount / brightnessList.length;

  // If more than 40% of pixels are dark, consider this a filled bubble
  if (darkPixelPercentage > 0.4) {
    return medianBrightness ~/ 2; // Make it appear darker
  }

  return medianBrightness;
}

// Extract the answers from the bubble sheet based on the detected brightness
Future<Map<int, String>> extractAnswers(File imageFile) async {
  final image = await loadImage(imageFile);
  Map<int, String> result = {};

  for (int col = 0; col < 3; col++) {
    for (int q = 0; q < questionsPerColumn; q++) {
      int questionNumber = col * questionsPerColumn + q + 1;
      int rowY = startY + (q * rowSpacing);
      int colX = startX + (col * columnSpacing);
      List<int> brightness = [];

      for (int opt = 0; opt < 4; opt++) {
        int x = colX + (opt * colSpacing);
        int avg = getAverageBrightness(image, x, rowY);
        brightness.add(avg);
      }

      result[questionNumber] = getFilledBubble(brightness);
      print('Q$questionNumber brightness: $brightness');
    }
  }

  return result;
}

Future<void> visualizeBubblePositions(File inputFile, String outputPath) async {
  final bytes = await inputFile.readAsBytes();
  final image = img.decodeImage(bytes)!;

  final red = img.ColorRgb8(255, 0, 0);

  for (int col = 0; col < 3; col++) {
    for (int q = 0; q < questionsPerColumn; q++) {
      int rowY = startY + (q * rowSpacing);
      int colX = startX + (col * columnSpacing);

      for (int opt = 0; opt < 4; opt++) {
        int x = colX + (opt * colSpacing);

        img.drawRect(
          image,
          x1: x,
          y1: rowY,
          x2: x + bubbleWidth,
          y2: rowY + bubbleHeight,
          color: red,
        );
      }
    }
  }

  final output = File(outputPath);
  await output.writeAsBytes(img.encodeJpg(image));
}