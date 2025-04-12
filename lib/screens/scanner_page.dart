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
      appBar: AppBar(title: Text('Bubble Sheet Scanner')),
      body: Stack(
        children: [
          // Show camera preview if camera is initialized and controller is not null
          if (cameraService.controller != null && cameraService.controller!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(cameraService.controller!),  // Camera preview
            ),
          
          // Add a bubble position visualization
          if (cameraService.controller != null && cameraService.controller!.value.isInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: BubblePositionPainter(),  // New custom painter for bubble positions
              ),
            ),
          
          // Button to trigger bubble sheet scanning
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: scanBubbleSheet,
              child: Text("Scan"),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter to visualize bubble positions with numbers
class BubblePositionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final textPaint = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Visualize bubble positions with numbers
    for (int q = 0; q < 60; q++) {
      int rowY = startY + (q * rowSpacing);

      for (int opt = 0; opt < 4; opt++) {
        int x = startX + (opt * colSpacing);

        // Draw circle (representing bubble) at position (x, rowY)
        canvas.drawCircle(Offset(x + bubbleWidth / 2, rowY + bubbleHeight / 2), 20, paint);

        // Draw number in the center of the bubble
        textPaint.text = TextSpan(
          text: '${q + 1}',  // Display question number
          style: TextStyle(color: Colors.white, fontSize: 14),
        );
        textPaint.layout(minWidth: 0, maxWidth: double.infinity);
        textPaint.paint(canvas, Offset(x + bubbleWidth / 4, rowY + bubbleHeight / 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

