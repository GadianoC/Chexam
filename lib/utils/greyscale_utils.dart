import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';


/// Top-level function for isolate image processing
// Isolate entry point: processes bytes, returns PNG bytes
// Isolate entry point: processes bytes, returns PNG bytes (must be synchronous for compute)
List<int> convertToGreyscaleIsolate(Uint8List bytes) {
  // Decode image (in isolate)
  img.Image? image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');

  // Downscale if large (max width 1200px)
  if (image.width > 1200) {
    image = img.copyResize(image, width: 1200);
  }

  // Custom grayscale: use green channel to reduce color cast
  final customGreyscale = img.Image(width: image.width, height: image.height);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final g = pixel.g;
      customGreyscale.setPixel(x, y, img.ColorRgb8(g.toInt(), g.toInt(), g.toInt()));
    }
  }

  // Boost contrast
  final contrastImage = img.adjustColor(customGreyscale, contrast: 1.5);

  // Use a fixed threshold similar to Photoshop (e.g., 135)
  final thresholdValue = 135;
  final thresholded = img.Image(width: contrastImage.width, height: contrastImage.height);
  final black = img.ColorRgb8(0, 0, 0);
  final white = img.ColorRgb8(255, 255, 255);

  for (int y = 0; y < contrastImage.height; y++) {
    for (int x = 0; x < contrastImage.width; x++) {
      final pixel = contrastImage.getPixel(x, y);
      final luma = img.getLuminance(pixel);
      thresholded.setPixel(x, y, luma < thresholdValue ? black : white);
    }
  }

  // Encode PNG (in isolate)
  return img.encodePng(thresholded);
}

/// Converts an image file to greyscale PNG using an isolate, saves to temp, and returns the new File
Future<File> convertToGreyscale(File inputFile) async {
  final bytes = await inputFile.readAsBytes();
  final pngBytes = await compute(convertToGreyscaleIsolate, bytes);
  final tempDir = await getTemporaryDirectory();
  final output = File('${tempDir.path}/greyscale_${inputFile.uri.pathSegments.last}.png');
  await output.writeAsBytes(pngBytes);
  return output;
}