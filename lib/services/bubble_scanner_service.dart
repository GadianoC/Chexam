import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:ui';

// Labels for answer options (A, B, C, D) used in bubble sheet scanning
const List<String> optionLabels = ['A', 'B', 'C', 'D'];


class BubbleScannerService {
  static const double FILL_THRESHOLD = 0.5; // Minimum fill ratio for a bubble to be considered filled (adjust as needed)
  final _textRecognizer = TextRecognizer();

  /// Returns the (x, y) pixel position for a given row and column in the answer grid.
  Offset interpolateGridPoint(
    Offset topLeft,
    Offset topRight,
    Offset bottomRight,
    Offset bottomLeft,
    double row, // 0.0 = top, 1.0 = bottom
    double col, // 0.0 = left, 1.0 = right
  ) {
    // Interpolate along the left and right edges
    final left = Offset(
      topLeft.dx + (bottomLeft.dx - topLeft.dx) * row,
      topLeft.dy + (bottomLeft.dy - topLeft.dy) * row,
    );
    final right = Offset(
      topRight.dx + (bottomRight.dx - topRight.dx) * row,
      topRight.dy + (bottomRight.dy - topRight.dy) * row,
    );
    // Interpolate between left and right
    return Offset(
      left.dx + (right.dx - left.dx) * col,
      left.dy + (right.dy - left.dy) * col,
    );
  }

  static const int BUBBLE_SIZE_MIN = 20; // Minimum bubble size in pixels
  static const int BUBBLE_SIZE_MAX = 50; // Maximum bubble size in pixels
  /// Returns the four corners of the bubble sheet answer area in the order:
  /// [topLeft, topRight, bottomRight, bottomLeft].
  /// Adjust these values to match your template.
  List<Offset> getBubbleSheetCorners(int width, int height) {
    // Example: corners inset by 10% from each edge
    return [
      Offset(width * 0.10, height * 0.10), // topLeft
      Offset(width * 0.90, height * 0.10), // topRight
      Offset(width * 0.90, height * 0.90), // bottomRight
      Offset(width * 0.10, height * 0.90), // bottomLeft
    ];
  }

  Future<List<Map<String, double>>> scanBubbleSheet(String imagePath) async {
  final totalStart = DateTime.now();
  print('--- Bubble Scan Started ---');
  try {
    // Process the image
    final processStart = DateTime.now();
    final processedImage = await _processImage(imagePath);
    print('Image processed in: [32m${DateTime.now().difference(processStart).inMilliseconds} ms[0m');

    // Get image dimensions
    final width = processedImage.width;
    final height = processedImage.height;

    // --- DYNAMIC GRID INTERPOLATION LOGIC ---
    // You must provide the four corners of the answer area in this order:
    // [topLeft, topRight, bottomRight, bottomLeft]
    // For example, from MLKit or your perspective transform step.
    final List<Offset> corners = getBubbleSheetCorners(width, height); // <-- Now implemented

    List<Map<String, double>> bubbles = [];
    final bubbleStart = DateTime.now();
    // For each column (3 columns)
    for (int col = 0; col < 3; col++) {
      for (int row = 0; row < 20; row++) {
        Map<String, double> questionBubbles = {};
        // Compute normalized position in the grid
        double rowNorm = row / 19.0;
        double colNorm = col / 2.0;
        // Center of the question row in this column
        Offset questionCenter = interpolateGridPoint(
          corners[0], corners[1], corners[2], corners[3],
          rowNorm, colNorm,
        );
        // For each option (A, B, C, D), offset horizontally
        const double bubbleSpacing = 40.0; // Tune this value to match your template (in pixels)
        for (int opt = 0; opt < 4; opt++) {
          double optionOffset = (opt - 1.5) * bubbleSpacing;
          Offset bubbleCenter = questionCenter.translate(optionOffset, 0);
          // Check if this location contains a filled bubble
          final isFilled = _isBubbleFilled(processedImage, bubbleCenter.dx.round(), bubbleCenter.dy.round());
          questionBubbles[optionLabels[opt]] = isFilled ? 1.0 : 0.0;
        }
        bubbles.add(questionBubbles);
      }
    }
    print('Bubble detection in: [33m${DateTime.now().difference(bubbleStart).inMilliseconds} ms[0m');

    // Save debug image if needed
    await _saveDebugImage(processedImage);

    print('Total scan time: [36m${DateTime.now().difference(totalStart).inMilliseconds} ms[0m');
    print('--- Bubble Scan Finished ---');
    return bubbles;
    } catch (e) {
      print('Bubble scanning failed: $e');
      throw Exception('Bubble scanning failed: $e');
    }
  }
  
  bool _isBubbleFilled(img.Image image, int centerX, int centerY) {
    int darkPixels = 0;
    int totalPixels = 0;
    
    // Check pixels in a circular area around the center
    for (int y = -BUBBLE_SIZE_MIN; y <= BUBBLE_SIZE_MIN; y++) {
      for (int x = -BUBBLE_SIZE_MIN; x <= BUBBLE_SIZE_MIN; x++) {
        // Check if point is within bubble radius
        if (x * x + y * y <= BUBBLE_SIZE_MIN * BUBBLE_SIZE_MIN) {
          final pixelX = centerX + x;
          final pixelY = centerY + y;
          
          // Ensure pixel is within image bounds
          if (pixelX >= 0 && pixelX < image.width && pixelY >= 0 && pixelY < image.height) {
            final pixel = image.getPixel(pixelX, pixelY);
            final brightness = img.getLuminance(pixel);
            
            if (brightness < 128) { // Assuming 8-bit grayscale
              darkPixels++;
            }
            totalPixels++;
          }
        }
      }
    }
    
    // Calculate fill ratio
    final fillRatio = darkPixels / totalPixels;
    return fillRatio >= FILL_THRESHOLD;
  }
  
  Future<img.Image> _processImage(String imagePath) async {
  final processStart = DateTime.now();
  // Read the image
  final bytes = await File(imagePath).readAsBytes();
  print('Read image in: [34m${DateTime.now().difference(processStart).inMilliseconds} ms[0m');
  final decodeStart = DateTime.now();
  img.Image? image = img.decodeImage(bytes);
  print('Decoded image in: \u001b[34m${DateTime.now().difference(decodeStart).inMilliseconds} ms\u001b[0m');

  if (image == null) throw Exception('Failed to load image');

  // --- DOWNSCALE STEP ---
  final maxWidth = 1200;
  if (image.width > maxWidth) {
    final ratio = maxWidth / image.width;
    image = img.copyResize(image, width: maxWidth, height: (image.height * ratio).round());
    print('Downscaled image to width $maxWidth');
  }

  final grayscaleStart = DateTime.now();
  // Convert to grayscale
  final grayscale = img.grayscale(image);
  print('Grayscale in: \u001b[34m${DateTime.now().difference(grayscaleStart).inMilliseconds} ms\u001b[0m');

  final blurStart = DateTime.now();
  // Apply gaussian blur to reduce noise
  final blurred = img.gaussianBlur(grayscale, radius: 2);
  print('Blur in: [34m${DateTime.now().difference(blurStart).inMilliseconds} ms[0m');

  final contrastStart = DateTime.now();
  // Increase contrast to make bubbles more distinct
  final contrast = img.contrast(blurred, contrast: 2.0);
  print('Contrast in: [34m${DateTime.now().difference(contrastStart).inMilliseconds} ms[0m');

  final adjustStart = DateTime.now();
  // Convert to binary by adjusting brightness and contrast
  final processed = img.adjustColor(contrast,
    brightness: -50,
    contrast: 50,
    saturation: -100
  );
  print('Adjust color in: [34m${DateTime.now().difference(adjustStart).inMilliseconds} ms[0m');

  print('Total _processImage time: [35m${DateTime.now().difference(processStart).inMilliseconds} ms[0m');
  return processed;
} 
  
  Future<void> _saveDebugImage(img.Image image) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final debugImagePath = '${tempDir.path}/debug_processed.png';
      final debugFile = File(debugImagePath);
      await debugFile.writeAsBytes(img.encodePng(image));
    } catch (e) {
      print('Failed to save debug image: $e');
    }
  }
  
  void dispose() {
    _textRecognizer.close();
  }
}
