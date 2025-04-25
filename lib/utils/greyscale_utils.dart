import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';


/// Top-level function for isolate image processing
// Isolate entry point: processes bytes, returns PNG bytes
// Isolate entry point: processes bytes, returns PNG bytes (must be synchronous for compute)
/**
 * Decodes an image from bytes.
 */
img.Image decodeImageFromBytes(Uint8List bytes) {
  final stopwatch = Stopwatch()..start();
  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');
  stopwatch.stop();
  print('[TIME] [DEBUG] [decodeImageFromBytes] Took ${stopwatch.elapsedMilliseconds}ms');
  return image;
}

/**
 * Downscales the image if width exceeds maxWidth.
 */
img.Image downscaleImage(img.Image image, {required int maxWidth}) {
  final stopwatch = Stopwatch()..start();
  if (image.width > maxWidth) {
    final result = img.copyResize(image, width: maxWidth);
    stopwatch.stop();
    print('[TIME] [DEBUG] [downscaleImage] Took ${stopwatch.elapsedMilliseconds}ms');
    return result;
  }
  stopwatch.stop();
  print('[TIME] [DEBUG] [downscaleImage] Took ${stopwatch.elapsedMilliseconds}ms');
  return image;
}

/**
 * Converts an image to greyscale using the green channel for reduced color cast.
 */
img.Image toGreyscale(img.Image image) {
  final stopwatch = Stopwatch()..start();
  final greyscale = img.Image(width: image.width, height: image.height);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final g = pixel.g;
      greyscale.setPixel(x, y, img.ColorRgb8(g.toInt(), g.toInt(), g.toInt()));
    }
  }
  stopwatch.stop();
  print('[TIME] [DEBUG] [toGreyscale] Took ${stopwatch.elapsedMilliseconds}ms');
  return greyscale;
}

/**
 * Boosts contrast of the image.
 */
img.Image boostContrast(img.Image image, {required double contrast}) {
  final stopwatch = Stopwatch()..start();
  final result = img.adjustColor(image, contrast: contrast);
  stopwatch.stop();
  print('[TIME] [DEBUG] [boostContrast] Took ${stopwatch.elapsedMilliseconds}ms');
  return result;
}

/**
 * Applies a threshold to binarize the image.
 */
img.Image applyThreshold(img.Image image, int thresholdValue) {
  final stopwatch = Stopwatch()..start();
  final thresholded = img.Image(width: image.width, height: image.height);
  final black = img.ColorRgb8(0, 0, 0);
  final white = img.ColorRgb8(255, 255, 255);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final luma = img.getLuminance(pixel);
      thresholded.setPixel(x, y, luma < thresholdValue ? black : white);
    }
  }
  stopwatch.stop();
  print('[TIME] [DEBUG] [applyThreshold] Took ${stopwatch.elapsedMilliseconds}ms');
  return thresholded;
}

/**
 * Inverts a binary image (black <-> white).
 */
img.Image invertImage(img.Image image) {
  final stopwatch = Stopwatch()..start();
  final inverted = img.Image(width: image.width, height: image.height);
  final black = img.ColorRgb8(0, 0, 0);
  final white = img.ColorRgb8(255, 255, 255);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      inverted.setPixel(x, y, pixel.r == 0 ? white : black);
    }
  }
  stopwatch.stop();
  print('[TIME] [DEBUG] [invertImage] Took ${stopwatch.elapsedMilliseconds}ms');
  return inverted;
}

/**
 * Encodes an image as PNG bytes.
 */
List<int> encodeImageToPng(img.Image image) {
  final stopwatch = Stopwatch()..start();
  final result = img.encodePng(image);
  stopwatch.stop();
  print('[TIME] [DEBUG] [encodeImageToPng] Took ${stopwatch.elapsedMilliseconds}ms');
  return result;
}

/**
 * Saves an image as a PNG file and returns the File.
 */
Future<File> saveImageToFile(img.Image image, [String? filename]) async {
  final stopwatch = Stopwatch()..start();
  final now = DateTime.now().millisecondsSinceEpoch;
  final uniqueFilename = filename ?? 'greyscale_${now}.png';
  print('[DEBUG] [saveImageToFile] Writing image to file: $uniqueFilename');
  final tempDir = await getTemporaryDirectory();
  final output = File('${tempDir.path}/$uniqueFilename');
  await output.writeAsBytes(img.encodePng(image));
  print('[DEBUG] [saveImageToFile] Finished writing image to file: ${output.path}');
  stopwatch.stop();
  print('[TIME] [DEBUG] [saveImageToFile] Took ${stopwatch.elapsedMilliseconds}ms');
  return output;
}

/// Step-by-step processing pipeline
Future<File> processImageStepByStep(
  File inputFile, {
  int threshold = 100,
  bool invert = true,
  int maxWidth = 1200,
  double contrast = 2.0,
}) async {
  final stopwatch = Stopwatch()..start();
  print('[DEBUG] [processImageStepByStep] Starting image processing for: ${inputFile.path}');
  final inputExists = await inputFile.exists();
  print('[DEBUG] Input file exists: $inputExists');
  final inputLength = await inputFile.length();
  print('[DEBUG] Input file length: $inputLength bytes');

  final bytes = await inputFile.readAsBytes();
  print('[DEBUG] Read bytes length: ${bytes.length}');

  img.Image image;
  try {
    image = decodeImageFromBytes(bytes);
    print('[DEBUG] Decoded image: ${image.width}x${image.height}');
  } catch (e) {
    print('[ERROR] Failed to decode image: $e');
    rethrow;
  }

  image = downscaleImage(image, maxWidth: maxWidth);
  print('[DEBUG] After downscale: ${image.width}x${image.height}');
  image = toGreyscale(image);
  print('[DEBUG] After greyscale conversion');
  image = boostContrast(image, contrast: contrast);
  print('[DEBUG] After contrast boost');
  image = applyThreshold(image, threshold);
  print('[DEBUG] After thresholding');
  if (invert) {
    image = invertImage(image);
    print('[DEBUG] After inversion');
  }
  final outputFile = await saveImageToFile(image, 'greyscale_thresh_inv_${inputFile.uri.pathSegments.last}.png');
  final outputExists = await outputFile.exists();
  final outputLength = await outputFile.length();
  print('[DEBUG] Output file exists: $outputExists');
  print('[DEBUG] Output file path: ${outputFile.path}');
  print('[DEBUG] Output file length: $outputLength bytes');
  stopwatch.stop();
  print('[TIME] [DEBUG] Image processing took: ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(3)} seconds');
  return outputFile;
}
