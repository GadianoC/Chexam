import 'dart:typed_data';
import 'package:image/image.dart' as img;

class PreprocessRequest {
  final Uint8List bytes;
  final int maxWidth;
  final double contrast;
  final double brightness;
  PreprocessRequest({required this.bytes, this.maxWidth = 1200, this.contrast = 2.0, this.brightness = 1.1});
}

class PreprocessResult {
  final img.Image? processed;
  final String? error;
  PreprocessResult(this.processed, {this.error});
}

Future<PreprocessResult> preprocessImageIsolate(PreprocessRequest request) async {
  try {
    img.Image? original = img.decodeImage(request.bytes);
    if (original == null) return PreprocessResult(null, error: 'Failed to decode image');
    if (original.width > request.maxWidth) {
      original = img.copyResize(original, width: request.maxWidth);
    }
    final grayscale = img.grayscale(original);
    final enhanced = img.adjustColor(grayscale, contrast: request.contrast, brightness: request.brightness);
    final edges = img.sobel(enhanced);
    return PreprocessResult(edges);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
  } catch (e) {
    return PreprocessResult(null, error: e.toString());
  }
}

// Top-level entry point for compute/isolate
Future<PreprocessResult> preprocessImageEntry(PreprocessRequest request) async {
  return preprocessImageIsolate(request);
}
