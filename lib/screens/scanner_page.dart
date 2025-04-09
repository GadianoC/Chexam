import 'dart:io';  
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';  
import '../scanner/bubble_scanner.dart';  

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final cameraService = CameraService();  
  
  Map<int, String>? scannedAnswers;  

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
      final answers = await extractAnswers(file);  
      setState(() => scannedAnswers = answers);  
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    }
  }

  // Build the UI for ScannerPage with camera preview and results display
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bubble Sheet Scanner')),  
      body: Column(
        children: [
          // Show camera preview if camera is initialized and controller is not null
          if (cameraService.controller != null && cameraService.controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: cameraService.controller!.value.aspectRatio,  
              child: CameraPreview(cameraService.controller!),  
            ),
          
          // Button to trigger bubble sheet scanning
          ElevatedButton(onPressed: scanBubbleSheet, child: Text("Scan")),
          
          // Display scanned answers if available
          if (scannedAnswers != null)
            Expanded(
              child: ListView(
                children: scannedAnswers!.entries
                    .map((e) => ListTile(
                          title: Text("Q${e.key}: ${e.value}"),  
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
