import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceAngleDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FaceAngleDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _FaceAngleDetectionScreenState createState() => _FaceAngleDetectionScreenState();
}

class _FaceAngleDetectionScreenState extends State<FaceAngleDetectionScreen> {
  late CameraController _controller;
  late FaceDetector _faceDetector;
  Face? _currentFace;
  bool _isBusy = false;
  String _angleInfo = "Position your face in the frame";
  double _yaw = 0;
  double _roll = 0;
  double _pitch = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: true,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.cameras[1], // front camera
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller.initialize();
    _controller.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        setState(() {
          _currentFace = faces.first;
          _updateAngleValues();
        });
      } else {
        setState(() {
          _currentFace = null;
          _angleInfo = "No face detected";
        });
      }
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final rotation =
          InputImageRotationValue.fromRawValue(_controller.description.sensorOrientation);
      if (rotation == null) return null;

      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
      if (inputImageFormat == null) return null;

      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation, // used only in Android
          format: inputImageFormat!, // used only in iOS
          bytesPerRow: image.planes.first.bytesPerRow, // used only in iOS
        ),
      );
    } catch (e) {
      print("Error creating InputImage: $e");
      return null;
    }
  }

  void _updateAngleValues() {
    if (_currentFace == null) return;

    _yaw = _currentFace!.headEulerAngleY ?? 0;
    _roll = _currentFace!.headEulerAngleZ ?? 0;
    _pitch = _currentFace!.headEulerAngleX ?? 0;

    String yawStatus = _getYawStatus(_yaw);
    String rollStatus = _getRollStatus(_roll);
    String pitchStatus = _getPitchStatus(_pitch);

    setState(() {
      _angleInfo = """
      Horizontal: $yawStatus (${_yaw.toStringAsFixed(1)}°)
      Tilt: $rollStatus (${_roll.toStringAsFixed(1)}°)
      Vertical: $pitchStatus (${_pitch.toStringAsFixed(1)}°)
      """;
    });
  }

  String _getYawStatus(double angle) {
    if (angle > 20) return "Right";
    if (angle < -20) return "Left";
    return "Center";
  }

  String _getRollStatus(double angle) {
    if (angle > 15) return "Right tilt";
    if (angle < -15) return "Left tilt";
    return "Straight";
  }

  String _getPitchStatus(double angle) {
    if (angle > 15) return "Up";
    if (angle < -15) return "Down";
    return "Level";
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live Face Angle Detection')),
      body: Stack(
        children: [
          SizedBox(
            child: CameraPreview(_controller),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Face Orientation:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _angleInfo,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          if (_currentFace != null)
            CustomPaint(
              painter: FaceDetectorPainter(_currentFace!, _controller),
            ),
        ],
      ),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  final Face face;
  final CameraController cameraController;

  FaceDetectorPainter(this.face, this.cameraController);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    // Convert face rectangle from image coordinates to screen coordinates
    final scaleX = size.width / cameraController.value.previewSize!.height;
    final scaleY = size.height / cameraController.value.previewSize!.width;

    final Rect rect = Rect.fromLTRB(
      (face.boundingBox.left * scaleX),
      (face.boundingBox.top * scaleY),
      (face.boundingBox.right * scaleX),
      (face.boundingBox.bottom * scaleY),
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.face != face;
  }
}
