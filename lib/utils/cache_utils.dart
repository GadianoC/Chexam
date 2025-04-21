import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Deletes all PNG images in the temporary directory (cache).
Future<bool> clearImageCache() async {
  try {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(tempDir.path);
    final files = dir.listSync();
    int deleted = 0;
    for (var file in files) {
      if (file is File && file.path.endsWith('.png')) {
        await file.delete();
        deleted++;
      }
    }
    print('[DEBUG] [clearImageCache] Deleted $deleted PNG files from cache.');
    return true;
  } catch (e) {
    print('[ERROR] [clearImageCache] Failed to clear cache: $e');
    return false;
  }
}
