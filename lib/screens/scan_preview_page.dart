import 'dart:io';
import 'package:chexam_prototype/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../analysis/bubble_analysis.dart';
import '../analysis/bubble_overlay_painter.dart';
import '../analysis/bubble_config.dart';
import 'student_answer_page.dart';

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
  // ...existing fields...

  // Helper to map detected answers to bubble indices in the grid
  Set<int> _getFilledBubbleIndices() {
    Set<int> indices = {};
    for (var entry in _answers.entries) {
      final qIdx = entry.key - 1;
      final oIdx = 'ABCD'.indexOf(entry.value);
      // Bubble grid is ordered: (col 0 q0 A, col 0 q0 B, ..., col 0 q1 A, ...)
      final col = qIdx ~/ questionsPerColumn;
      final row = qIdx % questionsPerColumn;
      final baseIdx = col * questionsPerColumn * 4 + row * 4;
      final idx = baseIdx + oIdx;
      indices.add(idx);
    }
    return indices;
  }

  // ...existing fields...

  // Helper to build the full bubble grid for overlay
  List<Map<String, double>> _buildBubbleGrid() {
    List<Map<String, double>> grid = [];
    for (int col = 0; col < 3; col++) {
      for (int q = 0; q < questionsPerColumn; q++) {
        final rowY = startY + q * rowSpacing;
        final colX = startX + col * columnSpacing;
        for (int opt = 0; opt < 4; opt++) {
          final x = colX + opt * colSpacing;
          grid.add({
            'x': x,
            'y': rowY,
            'r': bubbleWidth / 2,
          });
        }
      }
    }
    return grid;
  }

  File? _greyscaleFile;
  bool _isProcessing = true;
  String? _error;

  Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _greyscaleFile = widget.imageFile; // Assume already processed
    _isProcessing = false;
    _error = null;
    print('[DEBUG] [ScanPreviewPage] Received image file: ${widget.imageFile.path}');
    widget.imageFile.length().then((size) {
      print('[DEBUG] [ScanPreviewPage] Image file size: ${size}');
      final fileName = widget.imageFile.uri.pathSegments.last;
      if (!fileName.startsWith('greyscale')) {
        print('[WARNING] [ScanPreviewPage] Received file does not appear to be processed: ${fileName}');
      }
    });
    print('[DEBUG] Overlay image file: [36m${_greyscaleFile?.path}[0m');
    _initAsync();
  }

  Future<void> _initAsync() async {
    if (_greyscaleFile != null) {
      final bytes = await _greyscaleFile!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        print('[DEBUG] Overlay image size: [36m${decoded.width}x${decoded.height}[0m');
      }
      final answers = await extractAnswers(_greyscaleFile!);
      setState(() {
        _answers = answers;
      });
    }
  }

  Future<void> _runBubbleDetection() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _answers = {};
    });
    try {
      await loadImage(_greyscaleFile ?? widget.imageFile); // If needed for side-effects
      final answers = await extractAnswers(_greyscaleFile ?? widget.imageFile);
      setState(() {
        _answers = answers;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
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
                                ? const Text('No image selected')
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(_greyscaleFile!, fit: BoxFit.cover),
                                      // Always show the grid overlay for alignment
                                      // Always show the grid overlay, with filled bubbles highlighted after extraction
                                      CustomPaint(
                                        painter: BubbleOverlayPainter(
                                          _buildBubbleGrid(),
                                          filledBubbleIndices: _answers.isNotEmpty ? _getFilledBubbleIndices() : null,
                                        ),
                                        child: Container(),
                                      ),
                                    ],
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
                                  await _runBubbleDetection();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudentAnswerPage(answers: _answers),
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
