import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Point;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class DocumentScannerService {
  // ===== Public API =====

  /// Scans a document from the given image path.
  Future<String> scanDocument(
    String imagePath, {
    bool enhanceImage = false,
    bool adjustPerspective = false,
  }) async {
    print('[DEBUG] [scanDocument] Called with imagePath: $imagePath, enhanceImage: $enhanceImage, adjustPerspective: $adjustPerspective');
    Stopwatch stopwatch = Stopwatch()..start();
    try {
      // Load the original image
      final bytes = await File(imagePath).readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception('Failed to load image');
      print('[DEBUG] [scanDocument] Loaded image: ${originalImage.width}x${originalImage.height}');
      print('[DEBUG] [scanDocument] Image loading time: ${stopwatch.elapsedMilliseconds}ms');

      // Check if image dimensions are reasonable for a bubble sheet
      final aspectRatio = originalImage.width / originalImage.height;
      print('[DEBUG] [scanDocument] Image aspect ratio: $aspectRatio');
      if (aspectRatio < 0.6 || aspectRatio > 0.9) {
        throw Exception('Please align the bubble sheet properly within the guides');
      }

      // Convert to grayscale and detect edges
      var processedImage = originalImage;
      
      if (adjustPerspective) {
        print('[DEBUG] [scanDocument] Adjusting perspective...');
        // Convert to grayscale and enhance edges
        final grayscale = img.grayscale(originalImage);
        final enhanced = img.adjustColor(grayscale, contrast: 1.5, brightness: 1.1);
        final edges = img.sobel(enhanced);
        print('[DEBUG] [scanDocument] Edges detected');
        print('[DEBUG] [scanDocument] Edge detection time: ${stopwatch.elapsedMilliseconds}ms');
        
        // Find document corners
        final detectedCorners = findDocumentCorners(edges);
        print('[DEBUG] [scanDocument] Detected corners: $detectedCorners');
        final corners = orderCorners(detectedCorners); // Ensures [topLeft, topRight, bottomRight, bottomLeft]
        print('[DEBUG] [scanDocument] Ordered corners: $corners');
        print('[DEBUG] [scanDocument] Corner finding time: ${stopwatch.elapsedMilliseconds}ms');
        
        // Verify we found a valid bubble sheet shape
        if (!isValidBubbleSheetShape(corners)) {
          print('[DEBUG] [scanDocument] Invalid bubble sheet shape!');
          throw Exception('Please align the bubble sheet properly within the guides');
        }
        
        // Apply perspective transform and crop to bubble sheet dimensions
        print('[DEBUG] [scanDocument] Passing corners to perspectiveTransform: $corners');
        processedImage = perspectiveTransform(originalImage, corners);
        print('[DEBUG] [scanDocument] Perspective transform time: ${stopwatch.elapsedMilliseconds}ms');
        
        // Crop to remove any excess margins
        final cropMargin = processedImage.width * 0.02; // 2% margin
        print('[DEBUG] [scanDocument] Cropping with margin: $cropMargin');
        processedImage = img.copyCrop(
          processedImage,
          x: cropMargin.round(),
          y: cropMargin.round(),
          width: processedImage.width - (cropMargin * 2).round(),
          height: processedImage.height - (cropMargin * 2).round(),
        );
        print('[DEBUG] [scanDocument] Cropping time: ${stopwatch.elapsedMilliseconds}ms');
      }

      // Enhance image if requested
      if (enhanceImage) {
        print('[DEBUG] [scanDocument] Enhancing image...');
        // Standardize size while maintaining aspect ratio
        final aspectRatio = processedImage.width / processedImage.height;
        final targetWidth = 2000; // Higher resolution
        final targetHeight = (targetWidth / aspectRatio).round();
        print('[DEBUG] [scanDocument] Resizing to: ${targetWidth}x${targetHeight}');
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
        print('[DEBUG] [scanDocument] Enhancement time: ${stopwatch.elapsedMilliseconds}ms');
      }
      
      // Save the processed image with high quality
      final tempDir = await getTemporaryDirectory();
      final processedPath = '${tempDir.path}/processed_document.jpg';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(processedImage, quality: 95));
      print('[DEBUG] [scanDocument] Saved processed image to: $processedPath');
      print('[DEBUG] [scanDocument] Saving time: ${stopwatch.elapsedMilliseconds}ms');
      
      print('[DEBUG] [scanDocument] Total time: ${stopwatch.elapsedMilliseconds}ms');
      return processedPath;
    } catch (e) {
      print('[ERROR] [scanDocument] Document scanning failed: $e');
      return imagePath; // Return original on error
    }
  }

  // ===== Validation & Utilities =====

  /// Orders the corners as [topLeft, topRight, bottomRight, bottomLeft]
  List<Point<int>> orderCorners(List<Point<int>> corners) {
    print('[DEBUG] [orderCorners] Input corners: $corners');
    if (corners.length != 4) {
      throw ArgumentError('Exactly 4 corners are required');
    }
    // Sort by y to get top and bottom points
    List<Point<int>> sortedByY = List.from(corners)..sort((a, b) => a.y.compareTo(b.y));
    List<Point<int>> top = sortedByY.sublist(0, 2);
    List<Point<int>> bottom = sortedByY.sublist(2, 4);
    // Sort top points by x (left to right)
    top.sort((a, b) => a.x.compareTo(b.x));
    // Sort bottom points by x (left to right)
    bottom.sort((a, b) => a.x.compareTo(b.x));
    final ordered = [
      top[0],    // topLeft
      top[1],    // topRight
      bottom[1], // bottomRight
      bottom[0], // bottomLeft
    ];
    print('[DEBUG] [orderCorners] Ordered corners: $ordered');
    return ordered;
  }

  /// Validate if the detected corners form a valid bubble sheet shape
  bool isValidBubbleSheetShape(List<Point<int>> corners) {
    print('[DEBUG] [isValidBubbleSheetShape] Corners: $corners');
    if (corners.length != 4) {
      print('[DEBUG] [isValidBubbleSheetShape] Failed: Not 4 corners');
      return false;
    }

    // Aspect ratio check
    final width = math.sqrt(math.pow(corners[1].x - corners[0].x, 2) + math.pow(corners[1].y - corners[0].y, 2));
    final height = math.sqrt(math.pow(corners[2].x - corners[1].x, 2) + math.pow(corners[2].y - corners[1].y, 2));
    final aspectRatio = width / height;
    print('[DEBUG] [isValidBubbleSheetShape] Calculated aspect ratio: $aspectRatio');
    if (aspectRatio < 0.6 || aspectRatio > 0.9) {
      print('[DEBUG] [isValidBubbleSheetShape] Failed: Aspect ratio out of range');
      return false;
    }

    // Minimum area check (shoelace formula)
    double area = 0;
    for (int i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      area += (corners[i].x * corners[j].y) - (corners[j].x * corners[i].y);
    }
    area = area.abs() / 2.0;
    print('[DEBUG] [isValidBubbleSheetShape] Area: $area');
    if (area < 10000) { // Minimum area threshold (tune as needed)
      print('[DEBUG] [isValidBubbleSheetShape] Failed: Area too small');
      return false;
    }

    // Convexity check (cross product sign should be consistent)
    bool isConvex = true;
    int? lastSign;
    for (int i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final c = corners[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      final sign = cross.sign.toInt();
      if (lastSign == null) {
        lastSign = sign;
      } else if (sign != 0 && sign != lastSign) {
        isConvex = false;
        break;
      }
    }
    print('[DEBUG] [isValidBubbleSheetShape] Convex: $isConvex');
    if (!isConvex) {
      print('[DEBUG] [isValidBubbleSheetShape] Failed: Not convex');
      return false;
    }

    // Angle check (all angles should be roughly 90±25 degrees)
    bool anglesOk = true;
    for (int i = 0; i < 4; i++) {
      final a = corners[(i - 1 + 4) % 4];
      final b = corners[i];
      final c = corners[(i + 1) % 4];
      final ab = Point(b.x - a.x, b.y - a.y);
      final cb = Point(b.x - c.x, b.y - c.y);
      final dot = ab.x * cb.x + ab.y * cb.y;
      final magAb = math.sqrt(ab.x * ab.x + ab.y * ab.y);
      final magCb = math.sqrt(cb.x * cb.x + cb.y * cb.y);
      final cosTheta = dot / (magAb * magCb);
      final angle = math.acos(cosTheta) * 180 / math.pi;
      print('[DEBUG] [isValidBubbleSheetShape] Angle at corner $i: $angle');
      if (angle < 65 || angle > 115) {
        anglesOk = false;
        print('[DEBUG] [isValidBubbleSheetShape] Failed: Angle $angle at corner $i out of range');
        break;
      }
    }
    if (!anglesOk) return false;

    print('[DEBUG] [isValidBubbleSheetShape] All geometric checks passed.');
    return true;
  }

  // ===== Core Image Processing =====

  List<Point<int>> findDocumentCorners(img.Image edges) {
    print('[DEBUG] [findDocumentCorners] Called');
    final width = edges.width;
    final height = edges.height;
    print('[DEBUG] [findDocumentCorners] Image size: ${width}x${height}');
    
    // Find the strongest edge points in each corner region
    final topLeft = _findStrongestEdgeInRegion(edges, 0, 0, width ~/ 3, height ~/ 3);
    final topRight = _findStrongestEdgeInRegion(edges, width * 2 ~/ 3, 0, width, height ~/ 3);
    final bottomLeft = _findStrongestEdgeInRegion(edges, 0, height * 2 ~/ 3, width ~/ 3, height);
    final bottomRight = _findStrongestEdgeInRegion(edges, width * 2 ~/ 3, height * 2 ~/ 3, width, height);
    print('[DEBUG] [findDocumentCorners] Raw corners: $topLeft, $topRight, $bottomLeft, $bottomRight');
    // Always order corners [topLeft, topRight, bottomRight, bottomLeft]
    final ordered = orderCorners([topLeft, topRight, bottomLeft, bottomRight]);
    print('[DEBUG] [findDocumentCorners] Ordered corners: $ordered');
    return ordered;
  }

  img.Image perspectiveTransform(img.Image source, List<Point<int>> corners) {
    print('[DEBUG] [perspectiveTransform] Called with corners: $corners');
    // Create output image with bubble sheet proportions (slightly narrower than A4)
    final outputWidth = 2000;
    final outputHeight = (outputWidth / 0.75).round(); // Bubble sheet ratio
    final output = img.Image(width: outputWidth, height: outputHeight);
    print('[DEBUG] [perspectiveTransform] Output size: ${outputWidth}x${outputHeight}');

    // Define target corners (clockwise from top-left)
    final targetCorners = [
      Point(0, 0),
      Point(outputWidth - 1, 0),
      Point(outputWidth - 1, outputHeight - 1),
      Point(0, outputHeight - 1),
    ];
    print('[DEBUG] [perspectiveTransform] Target corners: $targetCorners');

    // Calculate perspective transform matrix
    final matrix = _computePerspectiveMatrix(corners, targetCorners);
    print('[DEBUG] [perspectiveTransform] Perspective matrix: $matrix');

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
    print('[DEBUG] [perspectiveTransform] Transform complete.');
    return output;
  }

  // ===== Private Helpers =====

  Point<int> _findStrongestEdgeInRegion(img.Image edges, int startX, int startY, int endX, int endY, {int windowSize = 15}) {
    print('[DEBUG] [_findStrongestEdgeInRegion] Region: ($startX, $startY) to ($endX, $endY)');
    int strongestX = startX;
    int strongestY = startY;
    num maxSum = 0;

    for (int y = startY; y <= endY - windowSize; y++) {
      for (int x = startX; x <= endX - windowSize; x++) {
        num sum = 0;
        for (int dy = 0; dy < windowSize; dy++) {
          for (int dx = 0; dx < windowSize; dx++) {
            final pixel = edges.getPixel(x + dx, y + dy);
            sum += img.getLuminance(pixel);
          }
        }
        if (sum > maxSum) {
          maxSum = sum;
          strongestX = x + windowSize ~/ 2;
          strongestY = y + windowSize ~/ 2;
        }
      }
    }
    print('[DEBUG] [_findStrongestEdgeInRegion] Strongest window center: ($strongestX, $strongestY) sum: $maxSum');
    return Point(strongestX, strongestY);
  }

  List<double> _computePerspectiveMatrix(List<Point<int>> source, List<Point<int>> target) {
    final stopwatch = Stopwatch()..start();
    print('[DEBUG] [_computePerspectiveMatrix] Source: $source, Target: $target');
    // Standard 8x8 system for homography
    final A = List<double>.filled(8 * 8, 0.0);
    final b = List<double>.filled(8, 0.0);

    for (int i = 0; i < 4; i++) {
      final srcX = source[i].x.toDouble();
      final srcY = source[i].y.toDouble();
      final dstX = target[i].x.toDouble();
      final dstY = target[i].y.toDouble();

      // Row for u
      A[(2 * i) * 8 + 0] = srcX;
      A[(2 * i) * 8 + 1] = srcY;
      A[(2 * i) * 8 + 2] = 1;
      A[(2 * i) * 8 + 3] = 0;
      A[(2 * i) * 8 + 4] = 0;
      A[(2 * i) * 8 + 5] = 0;
      A[(2 * i) * 8 + 6] = -dstX * srcX;
      A[(2 * i) * 8 + 7] = -dstX * srcY;
      b[2 * i] = dstX;

      // Row for v
      A[(2 * i + 1) * 8 + 0] = 0;
      A[(2 * i + 1) * 8 + 1] = 0;
      A[(2 * i + 1) * 8 + 2] = 0;
      A[(2 * i + 1) * 8 + 3] = srcX;
      A[(2 * i + 1) * 8 + 4] = srcY;
      A[(2 * i + 1) * 8 + 5] = 1;
      A[(2 * i + 1) * 8 + 6] = -dstY * srcX;
      A[(2 * i + 1) * 8 + 7] = -dstY * srcY;
      b[2 * i + 1] = dstY;
    }

    final h = _gaussianElimination(A, b);
    // Homography matrix (3x3, last element is 1)
    final matrix = [
      h[0], h[1], h[2],
      h[3], h[4], h[5],
      h[6], h[7], 1.0
    ];
    print('[DEBUG] [_computePerspectiveMatrix] Calculated matrix: $matrix');
    stopwatch.stop();
    print('[TIME] [DEBUG] [_computePerspectiveMatrix] Took {stopwatch.elapsedMilliseconds}ms');
    return matrix;
  }

  List<double> _gaussianElimination(List<double> A, List<double> b) {
    final stopwatch = Stopwatch()..start();
    final n = 8;
    for (int i = 0; i < n; i++) {
      // Search for maximum in this column
      double maxEl = A[i * 8 + i];
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (A[k * 8 + i] > maxEl) {
          maxEl = A[k * 8 + i];
          maxRow = k;
        }
      }

      // Swap maximum row with current row
      for (int j = i; j < n; j++) {
        final temp = A[i * 8 + j];
        A[i * 8 + j] = A[maxRow * 8 + j];
        A[maxRow * 8 + j] = temp;
      }
      final temp = b[i];
      b[i] = b[maxRow];
      b[maxRow] = temp;

      // Make all rows below this one 0 in current column
      for (int k = i + 1; k < n; k++) {
        final c = -A[k * 8 + i] / A[i * 8 + i];
        for (int j = i; j < n; j++) {
          if (i == j) {
            A[k * 8 + j] = 0;
          } else {
            A[k * 8 + j] += c * A[i * 8 + j];
          }
        }
        b[k] += c * b[i];
      }
    }

    // Solve equation Ax=b for an upper triangular matrix A
    final x = List<double>.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = b[i] / A[i * 8 + i];
      for (int k = i - 1; k >= 0; k--) {
        b[k] -= A[k * 8 + i] * x[i];
      }
    }
    stopwatch.stop();
    print('[TIME] [DEBUG] [_gaussianElimination] Took ${stopwatch.elapsedMilliseconds}ms');
    return x;
  }

  Point<double> _applyPerspectiveTransform(List<double> matrix, double x, double y, {int? outputWidth, int? outputHeight}) {
    // Only log for the first pixel, four corners, and last pixel
    bool isCorner = false;
    if (outputWidth != null && outputHeight != null) {
      isCorner = (x == 0 && y == 0) ||
                 (x == outputWidth - 1 && y == 0) ||
                 (x == 0 && y == outputHeight - 1) ||
                 (x == outputWidth - 1 && y == outputHeight - 1) ||
                 (x == outputWidth - 1 && y == outputHeight - 1);
    }
    bool isFirst = (x == 0 && y == 0);
    bool isLast = (outputWidth != null && outputHeight != null && x == outputWidth - 1 && y == outputHeight - 1);
    final stopwatch = Stopwatch()..start();
    if (isFirst || isCorner || isLast) {
      print('[DEBUG] [_applyPerspectiveTransform] Input: ([36m$x, $y[0m), Matrix: $matrix');
    }
    final srcX = (matrix[0] * x + matrix[1] * y + matrix[2]) / (matrix[6] * x + matrix[7] * y + matrix[8]);
    final srcY = (matrix[3] * x + matrix[4] * y + matrix[5]) / (matrix[6] * x + matrix[7] * y + matrix[8]);
    if (isFirst || isCorner || isLast) {
      print('[DEBUG] [_applyPerspectiveTransform] Output: ([32m$srcX, $srcY[0m)');
      stopwatch.stop();
      print('[TIME] [DEBUG] [_applyPerspectiveTransform] Took ${stopwatch.elapsedMilliseconds}ms');
    }
    return Point(srcX, srcY);
  }
}