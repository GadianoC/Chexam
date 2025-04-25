import 'dart:io';
import 'package:chexam_prototype/services/document_scanner_service.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'image_preprocess_isolate.dart';
import 'package:path_provider/path_provider.dart';

class ScanGuard {
  static bool isScanRunning = false;
}

// ---- Constants ----
const int kDefaultMaxWidth = 1200;
const double kDefaultContrast = 2.0;
const double kDefaultBrightness = 1.1;

// ---- Timing Helper ----
Future<T> timeOperation<T>(String label, Future<T> Function() operation) async {
  final stopwatch = Stopwatch()..start();
  try {
    return await operation();
  } finally {
    stopwatch.stop();
    print('[TIME] [DEBUG] $label took [32m${stopwatch.elapsedMilliseconds}ms[0m');
  }
}

// ---- Error Logging Helper ----
void logError(String message, [String? context, dynamic error]) {
  print('[ERROR] $message${context != null ? ' | Context: $context' : ''}${error != null ? ' | Error: $error' : ''}');
}


/// Crops the largest detected document (bubble sheet) using ML Kit and returns the cropped file.
Future<File?> autoCropBubbleSheetWithMLKit() async {
  if (ScanGuard.isScanRunning) {
    print('[GUARD] Scan already running, aborting duplicate call.');
    return null;
  }
  ScanGuard.isScanRunning = true;
  print('[DEBUG] [autoCropBubbleSheetWithMLKit] START');
  final totalStopwatch = Stopwatch()..start();
  print('[DEBUG] Entered autoCropBubbleSheetWithMLKit');
  final documentScanner = DocumentScanner(
    options: DocumentScannerOptions(),
  );
  File? croppedFile;
  try {
    print('[DEBUG] Initializing document scan...');
    // Step 2: Scan for documents and check if any images were detected
    final results = await timeOperation('Document scan', () => documentScanner.scanDocument());
    print('[DEBUG] Scan results: images found = [32m${results.images.length}[0m');
    if (results.images.isNotEmpty) {
      final imagePath = results.images.first;
      print('[DEBUG] Using imagePath: $imagePath');
      final file = File(imagePath);

      // Step 3: Validate the existence and contents of the scanned image file
      print('[DEBUG] Checking if file exists: $imagePath');
      if (!file.existsSync()) {
        logError('Image file does not exist', imagePath, null);
        throw Exception('Image file does not exist: $imagePath');
      }
      print('[DEBUG] Reading bytes from file...');
      final bytes = await timeOperation('File read', () => file.readAsBytes());
      print('[DEBUG] Bytes read: ${bytes.length}');
      if (bytes.isEmpty) {
        logError('Image file is empty', imagePath, null);
        throw Exception('Image file is empty: $imagePath');
      }
      print('[DEBUG] Image file exists and is not empty.');
      print('Image path: $imagePath, size: [32m${bytes.length}[0m');

      // Step 4: Decode the image
      print('[DEBUG] Decoding image...');
      final originalImage = await timeOperation('Decode', () async => img.decodeImage(bytes));
      print('[DEBUG] Decoded image: [32m${originalImage != null ? 'success' : 'failure'}[0m');
      if (originalImage == null) {
        logError('Failed to decode image. Format may be unsupported or file is corrupted.', imagePath);
        throw Exception('Failed to decode image. Format may be unsupported or file is corrupted.');
      }

      // Step 5: Preprocess the image (downscale, grayscale, enhance, edge detection) using compute()
      print('[DEBUG] Preprocessing (compute isolate)...');
      final preprocessResult = await timeOperation('Preprocessing (compute)', () => compute(
        preprocessImageEntry,
        PreprocessRequest(
          bytes: bytes,
          maxWidth: kDefaultMaxWidth,
          contrast: kDefaultContrast,
          brightness: kDefaultBrightness,
        ),
      ));
      if (preprocessResult.error != null) {
        logError('Preprocessing failed', null, preprocessResult.error);
        throw Exception('Preprocessing failed: ${preprocessResult.error}');
      }
      final edges = preprocessResult.processed;
      if (edges == null) {
        logError('Preprocessing returned null image', imagePath);
        throw Exception('Preprocessing returned null image');
      }

      // Step 6: Detect document corners and validate the shape
      print('[DEBUG] Finding document corners...');
      final corners = await timeOperation('Corner detection', () async => DocumentScannerService().findDocumentCorners(edges));
      print('[DEBUG] Corners found: $corners');
      final isValid = corners.length == 4 && DocumentScannerService().isValidBubbleSheetShape(corners);
      print('[DEBUG] Is valid bubble sheet shape: $isValid');

      if (isValid) {
        // Step 7: If valid, perform perspective correction and save the rectified image
        print('[DEBUG] Performing perspective transformation...');
        print('[DEBUG] Output image size before transform: ${originalImage.width}x${originalImage.height}');
        final rectified = await timeOperation('Perspective transform', () async => DocumentScannerService().perspectiveTransform(originalImage, corners));
        print('[DEBUG] [autoCropBubbleSheetWithMLKit] Perspective transform DONE');
        croppedFile = await timeOperation('Save', () async {
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final outPath = '${tempDir.path}/bubble_rectified_$timestamp.png';
          final outFile = File(outPath);
          await outFile.writeAsBytes(img.encodePng(rectified));
          print('[DEBUG] [autoCropBubbleSheetWithMLKit] Save DONE: $outPath');
          return outFile;
        });
      } else {
        // Step 8: If not valid, save the original image as fallback
        croppedFile = await timeOperation('Save', () async {
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final outPath = '${tempDir.path}/bubble_invalid_$timestamp.png';
          final outFile = File(outPath);
          await outFile.writeAsBytes(img.encodePng(originalImage));
          print('[DEBUG] [autoCropBubbleSheetWithMLKit] Save fallback DONE: $outPath');
          return outFile;
        });
      }
    }
    totalStopwatch.stop();
    print('[TIME] [DEBUG] Total time for autoCropBubbleSheetWithMLKit: [32m${totalStopwatch.elapsedMilliseconds}ms[0m');
    print('[DEBUG] Returning croppedFile: [36m$croppedFile[0m');
    return croppedFile;
  } catch (e, st) {
    logError('autoCropBubbleSheetWithMLKit failed', null, e);
    print(st);
    return null;
  } finally {
    ScanGuard.isScanRunning = false;
  }
}
