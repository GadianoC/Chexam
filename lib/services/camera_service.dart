import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;

  // Initialize the camera service
  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw 'No cameras available';
      }
      controller = CameraController(cameras.first, ResolutionPreset.medium);
      await controller?.initialize();
    } catch (e) {
      throw 'Error initializing camera: $e';
    }
  }

  // Capture an image from the camera
  Future<XFile> captureImage() async {
    if (controller == null || !controller!.value.isInitialized) {
      throw 'Camera not initialized';
    }
    return controller!.takePicture();
  }

  // Dispose of the camera controller to free up resources
  void dispose() {
    controller?.dispose();
  }
}
