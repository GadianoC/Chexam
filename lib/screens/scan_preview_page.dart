import 'dart:io';
import 'package:chexam_prototype/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:chexam_prototype/services/bubble_scanner_service.dart';
// import '../scanner/bubble_overlay_painter.dart';
import 'student_answer_page.dart';
import 'package:chexam_prototype/utils/greyscale_utils.dart';


class ScanPreviewPage extends StatefulWidget {
  final File imageFile;

  const ScanPreviewPage({
    super.key,
    required this.imageFile,
  });

  @override
  State<ScanPreviewPage> createState() => _ScanPreviewPageState();
}

class _ScanPreviewPageState extends State<ScanPreviewPage> {
  final BubbleScannerService _bubbleScannerService = BubbleScannerService();
  File? _greyscaleFile;
  bool _isProcessing = true;
  String? _error;
  List<Map<String, double>> _detectedBubbles = [];

  @override
  void initState() {
    super.initState();
    print('[DEBUG] [ScanPreviewPage] Received image file: \\${widget.imageFile.path}');
    widget.imageFile.length().then((size) {
      print('[DEBUG] [ScanPreviewPage] Image file size: \\${size}');
    });
    _greyscaleFile = widget.imageFile; // Assume already processed
    _isProcessing = false;
    _error = null;
  }


  Future<void> _runBubbleDetection() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _detectedBubbles = [];
    });
    try {
      final bubbles = await _bubbleScannerService.scanBubbleSheet(widget.imageFile.path);
      setState(() {
        _detectedBubbles = bubbles;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  Map<int, String> _convertBubblesToAnswers(List<Map<String, double>> bubbles) {
    final answers = <int, String>{};
    for (int i = 0; i < bubbles.length; i++) {
      if (bubbles[i].isNotEmpty) {
        // Pick the choice with the highest confidence
        final best = bubbles[i].entries.reduce((a, b) => a.value > b.value ? a : b);
        answers[i + 1] = best.key; // Use i if your questions are 0-indexed
      }
    }
    return answers;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & Confirm'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Dispose of the preview image file if it exists
            try {
              final file = _greyscaleFile ?? widget.imageFile;
              print('[DEBUG] Attempting to delete file: \\${file.path}');
              final existsBefore = await file.exists();
              print('[DEBUG] File exists before delete: \\${existsBefore}');
              if (existsBefore) {
                await file.delete();
                final existsAfter = await file.exists();
                print('[DEBUG] File exists after delete: \\${existsAfter}');
                if (existsAfter) {
                  print('[WARNING] File was not deleted. It may still be in use.');
                } else {
                  print('[INFO] File deleted successfully.');
                }
              } else {
                print('[INFO] File did not exist before delete. Nothing to delete.');
              }
            } catch (e) {
              print('Failed to delete preview file: \\${e.runtimeType}: \\${e.toString()}');
            }
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomePage()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Review your scanned sheet below. Make sure the image is clear before processing.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: _greyscaleFile == null
                            ? const Center(child: CircularProgressIndicator())
                            : Image.file(
                                _greyscaleFile!,
                                fit: BoxFit.cover,
                              ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing || _greyscaleFile == null
                            ? null
                            : () async {
                                setState(() {
                                  _isProcessing = true;
                                  _error = null;
                                });
                                try {
                                  final bubbles = await _bubbleScannerService.scanBubbleSheet(_greyscaleFile!.path);
                                  final answers = _convertBubblesToAnswers(bubbles);
                                  setState(() {
                                    _isProcessing = false;
                                  });
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudentAnswerPage(answers: answers),
                                    ),
                                  );
                                } catch (e) {
                                  setState(() {
                                    _isProcessing = false;
                                    _error = e.toString();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.toString()}')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 3,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_circle_outline, size: 24),
                                  SizedBox(width: 12),
                                  Text('Get Answers'),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            // Loading or Error overlay
            if (_isProcessing || _error != null)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text('Processing image...', style: TextStyle(color: Colors.white)),
                        ] else if (_error != null) ...[
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error processing image:\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _runBubbleDetection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Try Again', style: TextStyle(fontSize: 18)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
