import 'package:chexam_prototype/utils/greyscale_utils.dart';
import 'package:flutter/material.dart';
import '../utils/mlkit_crop_utils.dart';
import '/widgets/loading_overlay.dart';
import 'package:chexam_prototype/screens/scan_preview_page.dart' as custom_nav;

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => ScannerPageState();
}

class ScannerPageState extends State<ScannerPage> {
  static bool hasScannedThisSession = false; // Prevent repeated scans per app session
  static bool _isCapturing = false;

  bool _isLoading = false;
  String? _error;

  ScannerPageState() {
    print('[DEBUG] ScannerPageState instance created: [36m${identityHashCode(this)}[0m');
  }
  @override
  void initState() {
    super.initState();
    print('[DEBUG] ScannerPage initState called. hasScannedThisSession=$hasScannedThisSession, _isCapturing=$_isCapturing, instance=${identityHashCode(this)}');
    // Only scan if not already scanned this session and not already capturing
    if (!hasScannedThisSession && !_isCapturing) {
      print('[DEBUG] About to trigger scan in ScannerPageState');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          print('[DEBUG] Triggering scan and setting hasScannedThisSession to true');
          hasScannedThisSession = true;
          _captureAndNavigate();
        });
      });
    } else {
      print('[GUARD] Scan not triggered: hasScannedThisSession=$hasScannedThisSession, _isCapturing=$_isCapturing');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _captureAndNavigate() async {
    print('[DEBUG] _captureAndNavigate called. _isCapturing=$_isCapturing, instance=${identityHashCode(this)}');
    if (_isCapturing) {
      print('[GUARD] Scan blocked: _isCapturing is true');
      return;
    }
    _isCapturing = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    print('[DEBUG] _captureAndNavigate called');
    print('[DEBUG] About to trigger scan from retry');
    try {
      final croppedFile = await autoCropBubbleSheetWithMLKit();
      if (croppedFile == null || !(await croppedFile.exists()) || (await croppedFile.length()) < 10000) {
        throw Exception('Failed to scan document: invalid or empty image. Please try rescanning.');
      }
      if (!mounted) return;
      final fileSize = await croppedFile.length();
      print('[DEBUG] [ScannerPage] New scan file: \\${croppedFile.path}, size: \\${fileSize}');
      // Process the cropped file before preview
      final processedFile = await processImageStepByStep(
        croppedFile,
        threshold: 105,
        invert: false, // Set to true if you want inverted preview
      );
      final processedFileSize = await processedFile.length();
      print('[DEBUG] [ScannerPage] Processed file: \\${processedFile.path}, size: \\${processedFileSize}');
      print('[DEBUG] [ScannerPage] Passing processed file to preview: \\${processedFile.path}');
      print('[DEBUG] [ScannerPage] Processed file size: \\${await processedFile.length()}');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => custom_nav.ScanPreviewPage(imageFile: processedFile),
        ),
      ).then((_) {
        print('[DEBUG] Returned from preview, resetting hasScannedThisSession and _isCapturing');
        ScannerPageState.hasScannedThisSession = false;
        ScannerPageState._isCapturing = false;
        print('[DEBUG] Scan completed, _isCapturing reset to false');
      });
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isCapturing = false;
        _error = e.toString();
      });
      print('[DEBUG] Scan completed, _isCapturing reset to false');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('Failed to process image: $e');
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    _isCapturing = false;
    ScanGuard.isScanRunning = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Sheet'),
        backgroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const LoadingOverlay(message: "Processing, please wait..."),
          if (!_isLoading && _error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error:\n_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _captureAndNavigate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isLoading && _error == null)
            Container(),
        ],
      ),
          );
        }
      }
      
