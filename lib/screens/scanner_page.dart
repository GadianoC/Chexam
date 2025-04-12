import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../scanner/bubble_scanner.dart';
import 'student_answer_page.dart';  // Import the updated results page
import '../scanner/scanner_config.dart';  // Import the scanner configuration constants

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final cameraService = CameraService();
  Map<int, String>? scannedAnswers;
  bool isDebugMode = true; // Set this as needed for production

  // Initialize camera service and handle errors during initialization
  @override
  void initState() {
    super.initState();
    cameraService.initializeCamera().then((_) {
      setState(() {});
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera initialization failed: $e')));
    });
  }

  // Dispose of camera resources when leaving the page
  @override
  void dispose() {
    cameraService.dispose();
    super.dispose();
  }

  // Capture image and process the bubble sheet for answers
  Future<void> scanBubbleSheet() async {
  try {
    final pic = await cameraService.captureImage();
    final file = File(pic.path);

    if (isDebugMode) {
      final debugPath = '${file.parent.path}/debug_bubbles.jpg';
      await visualizeBubblePositions(file, debugPath);
      print("Visualization saved to: $debugPath");
    }

    // Extract answers and navigate to the result page
    final answers = await extractAnswers(file);

    // Navigate to the StudentAnswerPage to show the results
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentAnswerPage(answers: answers),  // Passing the answers
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
  }
}

  // Build the UI for ScannerPage with camera preview and scan button
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bubble Sheet Scanner'),
        backgroundColor: Colors.black.withOpacity(0.7),
      ),
      extendBodyBehindAppBar: true, // Make body extend behind app bar
      body: Stack(
        children: [
          // Show camera preview if camera is initialized and controller is not null
          if (cameraService.controller != null && cameraService.controller!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(cameraService.controller!),
            ),
          
          // Add a bubble position visualization
          if (cameraService.controller != null && cameraService.controller!.value.isInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: BubblePositionPainter(),
              ),
            ),
          
          // Add camera guide overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: scanBubbleSheet,
        child: Icon(Icons.camera),
        backgroundColor: Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// Custom painter to visualize bubble positions with numbers
class BubblePositionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.9)  // Changed to semi-transparent green for better visibility
      ..style = PaintingStyle.stroke  // Changed to stroke style
      ..strokeWidth = 2.0;

    final textPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Scale factors to adjust for different screen sizes
    double scaleX = size.width / 1080;  // Assuming 1080p as base resolution
    double scaleY = size.height / 1920;

    // Visualize bubble positions for each column
    for (int col = 0; col < 3; col++) {
      for (int q = 0; q < questionsPerColumn; q++) {
        int questionNumber = col * questionsPerColumn + q + 1;
        double rowY = (startY + (q * rowSpacing)) * scaleY;
        double colX = (startX + (col * columnSpacing)) * scaleX;

        for (int opt = 0; opt < 4; opt++) {
          double x = colX + (opt * colSpacing) * scaleX;
          double bubbleLeft = x;
          double bubbleTop = rowY;
          
          // Draw rectangle for bubble position
          canvas.drawRect(
            Rect.fromLTWH(
              bubbleLeft,
              bubbleTop,
              bubbleWidth * scaleX,
              bubbleHeight * scaleY,
            ),
            paint,
          );

          // Draw option letter (A, B, C, D)
          if (q == 0) {  // Only draw letters for the first row of each column
            textPaint.text = TextSpan(
              text: String.fromCharCode(65 + opt),  // 65 is ASCII 'A'
              style: TextStyle(
                color: Colors.white,
                fontSize: 12 * scaleX,
                fontWeight: FontWeight.bold,
              ),
            );
            textPaint.layout(minWidth: 0, maxWidth: double.infinity);
            textPaint.paint(
              canvas,
              Offset(
                bubbleLeft + (bubbleWidth * scaleX - textPaint.width) / 2,
                bubbleTop - 20 * scaleY,
              ),
            );
          }
        }

        // Draw question number
        textPaint.text = TextSpan(
          text: '$questionNumber',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12 * scaleX,
            fontWeight: FontWeight.bold,
          ),
        );
        textPaint.layout(minWidth: 0, maxWidth: double.infinity);
        textPaint.paint(
          canvas,
          Offset(
            colX - 25 * scaleX,
            rowY + (bubbleHeight * scaleY - textPaint.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
