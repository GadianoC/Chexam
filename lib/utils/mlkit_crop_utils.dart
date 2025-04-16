import 'dart:io';
import 'package:chexam_prototype/services/document_scanner_service.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';


/// Crops the largest detected document (bubble sheet) using ML Kit and returns the cropped file.
Future<File?> autoCropBubbleSheetWithMLKit() async {
  final documentScanner = DocumentScanner(
    options: DocumentScannerOptions(
    ),
  );

  File? croppedFile;
  try {
    final results = await documentScanner.scanDocument();
    if (results.images.isNotEmpty) {
      final imagePath = results.images.first;
      final file = File(imagePath);
      if (!file.existsSync()) {
        print('Image file does not exist: $imagePath');
        throw Exception('Image file does not exist: $imagePath');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        print('Image file is empty: $imagePath');
        throw Exception('Image file is empty: $imagePath');
      }
      print('Image path: $imagePath, size: ${bytes.length}');
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        print('Failed to decode image. Format may be unsupported or file is corrupted.');
        throw Exception('Failed to decode image. Format may be unsupported or file is corrupted.');
      }
      // Perspective correction integration
      final grayscale = img.grayscale(originalImage);
      final enhanced = img.adjustColor(grayscale, contrast: 1.5, brightness: 1.1);
      final edges = img.sobel(enhanced);
      final corners = DocumentScannerService().findDocumentCorners(edges);
      if (corners.length == 4 && DocumentScannerService().isValidBubbleSheetShape(corners)) {
        final rectified = DocumentScannerService().perspectiveTransform(originalImage, corners);
        final tempDir = await getTemporaryDirectory();
        croppedFile = File('${tempDir.path}/mlkit_rectified_bubble_sheet.png');
        await croppedFile.writeAsBytes(img.encodePng(rectified));
      } else {
        // Fallback: save the original image if perspective correction fails
        final tempDir = await getTemporaryDirectory();
        croppedFile = File('${tempDir.path}/mlkit_cropped_bubble_sheet.png');
        await croppedFile.writeAsBytes(img.encodePng(originalImage));
      }
    }
  } catch (e) {
    print('ML Kit document detection failed: $e');
    return null;
  } finally {
    await documentScanner.close();
  }
  return croppedFile;
}
