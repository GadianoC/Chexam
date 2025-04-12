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

      // Select the first available camera, you could enhance this later to allow for camera switching
      final selectedCamera = cameras.first;
      
      // You can customize the resolution here based on your needs
      controller = CameraController(selectedCamera, ResolutionPreset.medium);

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
