import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Point;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class DocumentScannerService {
  /// Validate if the detected corners form a valid bubble sheet shape
  bool isValidBubbleSheetShape(List<Point<int>> corners) {
    if (corners.length != 4) return false;

    // Calculate aspect ratio of the detected shape
    final width = math.sqrt(math.pow(corners[1].x - corners[0].x, 2) + 
                          math.pow(corners[1].y - corners[0].y, 2));
    final height = math.sqrt(math.pow(corners[2].x - corners[1].x, 2) + 
                           math.pow(corners[2].y - corners[1].y, 2));
    final aspectRatio = width / height;

    // Bubble sheet should be roughly portrait orientation with aspect ratio ~0.7-0.8
    return aspectRatio >= 0.6 && aspectRatio <= 0.9;
  }

  Future<String> scanDocument(
    String imagePath, {
    bool enhanceImage = false,
    bool adjustPerspective = false,
  }) async {
    try {
      // Load the original image
      final bytes = await File(imagePath).readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception('Failed to load image');

      // Check if image dimensions are reasonable for a bubble sheet
      final aspectRatio = originalImage.width / originalImage.height;
      if (aspectRatio < 0.6 || aspectRatio > 0.9) {
        throw Exception('Please align the bubble sheet properly within the guides');
      }

      // Convert to grayscale and detect edges
      var processedImage = originalImage;
      
      if (adjustPerspective) {
        // Convert to grayscale and enhance edges
        final grayscale = img.grayscale(originalImage);
        final enhanced = img.adjustColor(grayscale, contrast: 1.5, brightness: 1.1);
        final edges = img.sobel(enhanced);
        
        // Find document corners
        final corners = findDocumentCorners(edges);
        
        // Verify we found a valid bubble sheet shape
        if (!isValidBubbleSheetShape(corners)) {
          throw Exception('Please align the bubble sheet properly within the guides');
        }
        
        // Apply perspective transform and crop to bubble sheet dimensions
        processedImage = perspectiveTransform(originalImage, corners);
        
        // Crop to remove any excess margins
        final cropMargin = processedImage.width * 0.02; // 2% margin
        processedImage = img.copyCrop(
          processedImage,
          x: cropMargin.round(),
          y: cropMargin.round(),
          width: processedImage.width - (cropMargin * 2).round(),
          height: processedImage.height - (cropMargin * 2).round(),
        );
      }

      // Enhance image if requested
      if (enhanceImage) {
        // Standardize size while maintaining aspect ratio
        final aspectRatio = processedImage.width / processedImage.height;
        final targetWidth = 2000; // Higher resolution
        final targetHeight = (targetWidth / aspectRatio).round();
        processedImage = img.copyResize(
          processedImage,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.cubic,
        );

        // Enhance contrast and sharpness
        processedImage = img.adjustColor(
          processedImage,
          contrast: 1.2,
          brightness: 1.1,
        );
        processedImage = img.gaussianBlur(processedImage, radius: 1);
      }
      
      // Save the processed image with high quality
      final tempDir = await getTemporaryDirectory();
      final processedPath = '${tempDir.path}/processed_document.jpg';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(processedImage, quality: 95));
      
      return processedPath;
    } catch (e) {
      print('Document scanning failed: $e');
      return imagePath; // Return original on error
    }
  }

  List<Point<int>> findDocumentCorners(img.Image edges) {
    final width = edges.width;
    final height = edges.height;
    
    // Find the strongest edge points in each corner region
    final topLeft = _findStrongestEdgeInRegion(edges, 0, 0, width ~/ 3, height ~/ 3);
    final topRight = _findStrongestEdgeInRegion(edges, width * 2 ~/ 3, 0, width, height ~/ 3);
    final bottomLeft = _findStrongestEdgeInRegion(edges, 0, height * 2 ~/ 3, width ~/ 3, height);
    final bottomRight = _findStrongestEdgeInRegion(edges, width * 2 ~/ 3, height * 2 ~/ 3, width, height);
    
    return [topLeft, topRight, bottomLeft, bottomRight];
  }

  Point<int> _findStrongestEdgeInRegion(img.Image edges, int startX, int startY, int endX, int endY) {
    int strongestX = startX;
    int strongestY = startY;
    num maxStrength = 0;

    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final pixel = edges.getPixel(x, y);
        final strength = img.getLuminance(pixel);
        if (strength > maxStrength) {
          maxStrength = strength;
          strongestX = x;
          strongestY = y;
        }
      }
    }
    
    return Point(strongestX, strongestY);
  }

  img.Image perspectiveTransform(img.Image source, List<Point<int>> corners) {
    // Create output image with bubble sheet proportions (slightly narrower than A4)
    final outputWidth = 2000;
    final outputHeight = (outputWidth / 0.75).round(); // Bubble sheet ratio
    final output = img.Image(width: outputWidth, height: outputHeight);

    // Define target corners (clockwise from top-left)
    final targetCorners = [
      Point(0, 0),
      Point(outputWidth - 1, 0),
      Point(outputWidth - 1, outputHeight - 1),
      Point(0, outputHeight - 1),
    ];

    // Calculate perspective transform matrix
    final matrix = _computePerspectiveMatrix(corners, targetCorners);

    // Apply transform to each pixel
    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        // Apply inverse transform to get source coordinates
        final srcCoords = _applyPerspectiveTransform(matrix, x.toDouble(), y.toDouble());
        final srcX = srcCoords.x.round();
        final srcY = srcCoords.y.round();

        // Sample the source pixel if it's within bounds
        if (srcX >= 0 && srcX < source.width && srcY >= 0 && srcY < source.height) {
          output.setPixel(x, y, source.getPixel(srcX, srcY));
        }
      }
    }

    return output;
  }

  List<double> _computePerspectiveMatrix(List<Point<int>> source, List<Point<int>> target) {
    // Simplified perspective matrix calculation
    // This is a basic implementation - for production, consider using a more robust matrix calculation
    final matrix = List<double>.filled(9, 0);
    matrix[8] = 1.0; // Set homogeneous coordinate

    // Calculate coefficients
    for (int i = 0; i < 4; i++) {
      final sx = source[i].x.toDouble();
      final sy = source[i].y.toDouble();
      final tx = target[i].x.toDouble();
      final ty = target[i].y.toDouble();

      matrix[0] += sx * tx;
      matrix[1] += sx * ty;
      matrix[2] += sx;
      matrix[3] += sy * tx;
      matrix[4] += sy * ty;
      matrix[5] += sy;
      matrix[6] += tx;
      matrix[7] += ty;
    }

    // Normalize matrix
    for (int i = 0; i < 8; i++) {
      matrix[i] /= 4;
    }

    return matrix;
  }

  Point<double> _applyPerspectiveTransform(List<double> matrix, double x, double y) {
    final w = matrix[6] * x + matrix[7] * y + matrix[8];
    final px = (matrix[0] * x + matrix[1] * y + matrix[2]) / w;
    final py = (matrix[3] * x + matrix[4] * y + matrix[5]) / w;
    return Point(px, py);
  }
}
