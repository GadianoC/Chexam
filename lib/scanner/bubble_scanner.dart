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
    int count = 0;

    for (int dx = 0; dx < bubbleWidth; dx++) {
      for (int dy = 0; dy < bubbleHeight; dy++) {
        int px = x + dx;
        int py = y + dy;

        // Only sample if within bounds
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          final pixel = image.getPixel(px, py);
          final gray = ((pixel.r + pixel.g + pixel.b) ~/ 3);
          total += gray;
          count++;
        }
      }
    }

    return count == 0 ? 255 : total ~/ count; // Avoid division by 0
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
      print('Q${q + 1} brightness: $brightness');
    }

    return result;
  }


  Future<void> visualizeBubblePositions(File inputFile, String outputPath) async {
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes)!;

    final red = img.ColorRgb8(255, 0, 0);

    for (int q = 0; q < 60; q++) {
      int rowY = startY + (q * rowSpacing);

      for (int opt = 0; opt < 4; opt++) {
        int x = startX + (opt * colSpacing);

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

    final output = File(outputPath);
    await output.writeAsBytes(img.encodeJpg(image));
  }