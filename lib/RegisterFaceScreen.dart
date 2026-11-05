import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:face_detection_app/FaceEmbedding.dart';
import 'package:face_detection_app/models/FaceData.dart';
import 'package:face_detection_app/providers/api_face_detector_notifier.dart';
import 'package:face_detection_app/utils/app_dialogs.dart';
import 'package:face_detection_app/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as Img;
import 'package:timer_count_down/timer_controller.dart';
import 'package:timer_count_down/timer_count_down.dart';

class RegisterFaceScreen extends ConsumerStatefulWidget {
  final String name;
  RegisterFaceScreen({required this.name});
  @override
  _RegisterFaceScreenState createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends ConsumerState<RegisterFaceScreen> {
  CameraController? _controller;
  late FaceDetector _faceDetector;
  Face? _currentFace;
  bool _isBusy = false;
  String _angleInfo = "Position your face in the frame";
  double _yaw = 0;
  double _roll = 0;
  double _pitch = 0;
  List<CameraDescription> cameraList = [];
  List<Uint8List?> capturedImages = List.generate(5, (value) => null);
  final CountdownController _countdownController =
      CountdownController(autoStart: true);
  bool countdownHide = true;
  List<double> currentFaceEmbedding = [];
  Img.Image? currentCroppedImage;

  String displayImage = "assets/images/head_straight.png";
  List<String> facePoses = [
    'assets/images/head_straight.png',
    'assets/images/head_left.png',
    'assets/images/head_right.png',
    'assets/images/head_up.png',
    'assets/images/head_down.png',
  ];
  int currentFacePose = -1;

  @override
  void initState() {
    super.initState();
    _initCamera();
    // Only bounding box + head Euler angles are used downstream, so
    // tracking/landmarks/classification are left off to keep each frame's
    // detection pass cheap.
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        countdownHide = false;
      });
      _countdownController.start();
    });
  }

  // @override
  // void initState() {
  //   super.initState();
  //   _initCamera();
  // }

  Future<void> _initCamera() async {
    cameraList = await availableCameras();
    _controller = CameraController(cameraList[1], ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21); // use front camera
    await _controller!.initialize();
    double? zoomLevelMax = await _controller?.getMaxZoomLevel();
    print(zoomLevelMax);
    if (zoomLevelMax != null) {
      await _controller?.setZoomLevel(1.3);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _controller == null || !_controller!.value.isInitialized
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 40),
                _buildHeader(),
                const SizedBox(height: 10),
                _buildReferencePose(),
                const SizedBox(height: 10),
                _buildCameraPreview(),
                const SizedBox(height: 10),
                _buildRetakeButton(),
                const SizedBox(height: 20),
                _buildPoseOptions(),
                Container(
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
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.arrow_back, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Text(
            "Facial Attendance",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildReferencePose() {
    return Column(
      children: [
        Text(
            "Look at your face in the camera and move it the same way as shown in the reference"),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width,
          color: Colors.deepPurple,
          child: Column(
            children: [
              Text(
                  (currentFacePose == -1)
                      ? "Straight"
                      : (currentFacePose == 0)
                          ? "Left"
                          : (currentFacePose == 1)
                              ? "Right"
                              : (currentFacePose == 2)
                                  ? "Up"
                                  : (currentFacePose == 3)
                                      ? "Down"
                                      : "Straight",
                  style: TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              Image.asset(displayImage,
                  height: 80), // use your reference image here
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    final aspectRatio = _controller!.value.aspectRatio;
    return Container(
      width: 250.w,
      height: 250.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.purple, width: 5),
      ),
      child: ClipOval(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            // width: aspectRatio >= 1 ? 200.w * aspectRatio : 200.w,
            // height: aspectRatio >= 1 ? 340.h : 340.h / aspectRatio,
            width: 250.w,
            height: 250.w * aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_controller!),
                Positioned(
                  child: Visibility(
                    visible: !countdownHide,
                    child: Countdown(
                      controller: _countdownController,
                      seconds: 4,
                      build: (_, double time) => Text(
                        time.toInt().toString(),
                        style: TextStyle(
                          fontSize: 40,
                          color: Colors.blue,
                        ),
                      ),
                      interval: Duration(milliseconds: 100),
                      onFinished: () async {
                        // Retake or capture logic
                        await _controller
                            ?.startImageStream(_processCameraImage);
                        setState(() {
                          countdownHide = true;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetakeButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: Colors.deepPurple),
      iconSize: 40,
      onPressed: () async {
        // Retake or capture logic
        await _controller?.startImageStream(_processCameraImage);
      },
    );
  }

  Widget _buildPoseOptions() {
    List<String> poses = [
      'assets/images/head_straight.png',
      'assets/images/head_left.png',
      'assets/images/head_right.png',
      'assets/images/head_up.png',
      'assets/images/head_down.png',
    ];

    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        itemBuilder: (context, index) {
          return Container(
            height: 100.h,
            width: 63.w,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: capturedImages[index] != null
                ? Image.memory(capturedImages[index] as Uint8List, height: 50)
                : Image.asset(poses[index], height: 50),
          );
        },
        itemCount: 5,
      ),
    );
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
        });
        await _updateAngleValues(
            face: faces.first, inputImage: inputImage, cameraImage: image);
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
      final rotation = InputImageRotationValue.fromRawValue(
          _controller!.description.sensorOrientation);
      if (rotation == null) return null;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw);
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

  Future<void> _updateAngleValues({
    required Face face,
    required CameraImage cameraImage,
    required InputImage inputImage,
  }) async {
    if (_currentFace == null) return;

    _yaw = _currentFace!.headEulerAngleY ?? 0;
    _roll = _currentFace!.headEulerAngleZ ?? 0;
    _pitch = _currentFace!.headEulerAngleX ?? 0;
    int faceHorizontal = -2;
    if (Platform.isIOS) {
      faceHorizontal = _yaw > 25
          ? 1
          : _yaw < -25
              ? -1
              : 0;
    } else {
      faceHorizontal = _yaw > 25
          ? -1
          : _yaw < -25
              ? 1
              : 0;
    }
    int faceTilt = _roll > 10
        ? 1
        : _roll < -10
            ? -1
            : 0;
    int faceVertical = _pitch > 20
        ? 1
        : _pitch < -20
            ? -1
            : 0;

    if (faceHorizontal == 0 &&
        faceTilt == 0 &&
        faceVertical == 0 &&
        currentFacePose == -1) {
      Img.Image croppedImage = await cropFace1(Crop1DataInput(
          face: face, cameraImage: cameraImage, camera: cameraList[1]));
      List<double> faceEmbedding =
          await FaceEmbedding1.instance.getFaceEmbedding(croppedImage);
      if (kDebugMode) print("Face Embedding: $faceEmbedding");
      currentFaceEmbedding = faceEmbedding;
      currentCroppedImage = croppedImage;
      // _faceEmbedding.disposeModels();
      ({FaceData? faceData, double similarity})? recognizedFaceData = await _recognizeFace(faceEmbedding, ref);
      // await Future.delayed(Duration(seconds: 1));
      if (recognizedFaceData != null) {
        print('Recognized face: ${recognizedFaceData.faceData?.name??""}');
        Fluttertoast.showToast(msg: 'Face Already Registered');
        await AppDialogs.showImageMatchDialog(context, imageA: croppedImage!, imageB: Img.Image.fromBytes(recognizedFaceData.faceData!.faceWidth!, recognizedFaceData.faceData!.faceHeight!, recognizedFaceData.faceData!.faceBytes!), confidence: recognizedFaceData.similarity);
        Navigator.popUntil(context, (route)=>route.isFirst);
      } else {
        setState(() {
          capturedImages[0] = (Img.encodePng(croppedImage)) as Uint8List;
          displayImage = 'assets/images/head_left.png';
          currentFacePose = 0;
        });
      }
    } else if (faceHorizontal == -1 &&
        faceTilt == 0 &&
        faceVertical == 0 &&
        currentFacePose == 0) {
      Img.Image croppedImage = await cropFace1(Crop1DataInput(
          face: face, cameraImage: cameraImage, camera: cameraList[1]));
      setState(() {
        capturedImages[1] = (Img.encodePng(croppedImage)) as Uint8List;
        displayImage = 'assets/images/head_right.png';
        currentFacePose = 1;
      });
    } else if (faceHorizontal == 1 &&
        faceTilt == 0 &&
        faceVertical == 0 &&
        currentFacePose == 1) {
      Img.Image croppedImage = await cropFace1(Crop1DataInput(
          face: face, cameraImage: cameraImage, camera: cameraList[1]));
      setState(() {
        capturedImages[2] = (Img.encodePng(croppedImage)) as Uint8List;
        displayImage = 'assets/images/head_up.png';
        currentFacePose = 2;
      });
    } else if (faceHorizontal == 0 &&
        faceTilt == 0 &&
        faceVertical == 1 &&
        currentFacePose == 2) {
      Img.Image croppedImage = await cropFace1(Crop1DataInput(
          face: face, cameraImage: cameraImage, camera: cameraList[1]));
      setState(() {
        capturedImages[3] = (Img.encodePng(croppedImage)) as Uint8List;
        displayImage = 'assets/images/head_down.png';
        currentFacePose = 3;
      });
    } else if (faceHorizontal == 0 &&
        faceTilt == 0 &&
        faceVertical == -1 &&
        currentFacePose == 3) {
      Img.Image croppedImage = await cropFace1(Crop1DataInput(
          face: face, cameraImage: cameraImage, camera: cameraList[1]));
      setState(() {
        capturedImages[4] = (Img.encodePng(croppedImage)) as Uint8List;
        displayImage = 'assets/images/head_straight.png';
        currentFacePose = 4;
      });

      // croppedImage.;
      await ref
          .read(databaseProvider)
          .faceEmbeddingsDao
          .insertFace(widget.name, currentFaceEmbedding, currentCroppedImage!.height,currentCroppedImage!.width,currentCroppedImage!.getBytes());
      Fluttertoast.showToast(msg: "Registered Face");
      Navigator.pop(context);
    } else {
      setState(() {
        countdownHide = false;
      });
      _countdownController.restart();
    }

    String yawStatus = _getYawStatus(_yaw);
    String rollStatus = _getRollStatus(_roll);
    String pitchStatus = _getPitchStatus(_pitch);

    setState(() {
      _angleInfo = """
      Horizontal: $yawStatus (${_yaw.toStringAsFixed(1)}°)
      Vertical: $pitchStatus (${_pitch.toStringAsFixed(1)}°)
      """;
    });
  }

  String _getYawStatus(double angle) {
    if (angle > 15) return "Left";
    if (angle < -15) return "Right";
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

  Future<Img.Image> cropFace1(Crop1DataInput data) async {
    // Get image dimensions
    final width = data.cameraImage.width;
    final height = data.cameraImage.height;

    Img.Image img = Img.Image(width, height);
    if (data.cameraImage.format.group == ImageFormatGroup.yuv420) {
      // Convert YUV to RGB
      img = _convertYuv420ToRgb(data.cameraImage);
    } else if (data.cameraImage.format.group == ImageFormatGroup.nv21) {
      final orientation =
          WidgetsBinding.instance.window.physicalSize.aspectRatio > 1
              ? DeviceOrientation.landscapeLeft
              : DeviceOrientation.portraitUp;
      img = await convertSinglePlaneNv21ToRgb(
          data.cameraImage, data.camera, orientation);
    } else if (data.cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // Convert BGRA to Image
      img = Img.Image.fromBytes(
        width,
        height,
        data.cameraImage.planes[0].bytes,
        format: Img.Format.bgra,
      );
    } else {
      throw Exception(
          'Unsupported image format: ${data.cameraImage.format.group}');
    }

    // Get face bounding box
    final rect = data.face.boundingBox;
    final left = rect.left.toInt();
    final top = rect.top.toInt();
    final right = rect.right.toInt();
    final bottom = rect.bottom.toInt();

    // Calculate width and height of the bounding box
    final fWidth = right - left;
    final fHeight = bottom - top;

    // Debug the bounding box values
    print('Bounding box: left=$left, top=$top, width=$fWidth, height=$fHeight');

    // Ensure the bounding box is within image dimensions
    /*if (left < 0 || top < 0 || right > width || bottom > height) {
      print('Error: Bounding box is outside image dimensions!');
      return img; // Return the original image if the bounding box is invalid
    }*/

    // Crop the face
    return Img.copyCrop(img, left, top, fWidth, fHeight);
  }

  Img.Image _convertYuv420ToRgb(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final rgbImage = Img.Image(image.width, image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final yValue = yPlane.bytes[y * yPlane.bytesPerRow + x];
        final uValue = uPlane.bytes[(y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2)];
        final vValue = vPlane.bytes[(y ~/ 2) * vPlane.bytesPerRow + (x ~/ 2)];

        // Convert YUV to RGB
        final r = yValue + 1.402 * (vValue - 128);
        final g =
            yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
        final b = yValue + 1.772 * (uValue - 128);

        // Set the pixel in the Image object
        rgbImage.setPixelRgba(x, y, r.clamp(0, 255).toInt(),
            g.clamp(0, 255).toInt(), b.clamp(0, 255).toInt());
      }
    }

    return rgbImage;
  }

  Future<Img.Image> convertSinglePlaneNv21ToRgb(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    // Ensure the image has exactly 1 plane
    if (image.planes.length != 1) {
      throw Exception(
          'Expected 1 plane for single-plane NV21, but found ${image.planes.length}');
    }

    final plane =
        image.planes[0]; // Single plane containing Y and interleaved UV data
    final width = image.width;
    final height = image.height;

    // Create an empty RGB image
    Img.Image rgbImage = Img.Image(width, height);

    // The Y data occupies the first part of the plane
    final yData = plane.bytes;

    rgbImage = await compute(
        convertSinglePlaneNv21ToRgbCompute,
        ConvertNv21ToRgbaDataInput(
            height: height, width: width, yData: yData, rgbImage: rgbImage));

    // Calculate the rotation based on sensor orientation, device orientation, and lens direction
    final rotation = _calculateRotation(camera, deviceOrientation);

    // Rotate the image based on the calculated rotation
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        rgbImage = Img.copyRotate(rgbImage, 90);
        break;
      case InputImageRotation.rotation270deg:
        rgbImage = Img.copyRotate(rgbImage, -90);
        break;
      case InputImageRotation.rotation180deg:
        rgbImage = Img.copyRotate(rgbImage, 180);
        break;
      default:
        // No rotation needed
        break;
    }

    return rgbImage;
  }

  InputImageRotation _calculateRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;

    // Map device orientation to rotation compensation
    final _orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    var rotationCompensation = _orientations[deviceOrientation];
    if (rotationCompensation == null) {
      return InputImageRotation.rotation0deg; // Default to no rotation
    }

    if (camera.lensDirection == CameraLensDirection.front) {
      // Front-facing camera
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      // Back-facing camera
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }

    // Map rotation compensation to InputImageRotation
    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  Future<({FaceData? faceData, double similarity})?> _recognizeFace(List<double> faceData, WidgetRef ref) async {
    double threshold = 0.7;
    final allFaces =
        await ref.read(databaseProvider).faceEmbeddingsDao.getAllFaces();
    if (allFaces.length != 0) {
      for (final storedFace in allFaces) {
        double similarity = cosineSimilarity(
            faceData, Utils.parseEmbedding(storedFace.embedding!));
        if (similarity > threshold) {
          return (faceData: storedFace, similarity: similarity);;
        }
      }
      return null;
    } else {
      return null;
    }
  }

  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    // Ensure both embeddings have the same length
    if (embedding1.length != embedding2.length) {
      throw Exception('Embeddings must have the same length');
    }

    // Calculate the dot product
    double dotProduct = 0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    // Calculate the magnitudes (Euclidean norms)
    double magnitude1 = 0;
    double magnitude2 = 0;
    for (int i = 0; i < embedding1.length; i++) {
      magnitude1 += embedding1[i] * embedding1[i];
      magnitude2 += embedding2[i] * embedding2[i];
    }
    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    // Calculate cosine similarity
    if (magnitude1 == 0 || magnitude2 == 0) {
      throw Exception('Embeddings cannot have zero magnitude');
    }
    return dotProduct / (magnitude1 * magnitude2);
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}

class ConvertNv21ToRgbaDataInput {
  // final SendPort sendPort;
  final int height;
  final int width;
  final Uint8List yData;
  final Img.Image rgbImage;

  ConvertNv21ToRgbaDataInput({
    // required this.sendPort,
    required this.height,
    required this.width,
    required this.yData,
    required this.rgbImage,
  });
}

class Crop1DataInput {
  // final SendPort sendPort;
  final Face face;
  final CameraImage cameraImage;
  final CameraDescription camera;

  Crop1DataInput({
    // required this.sendPort,
    required this.face,
    required this.cameraImage,
    required this.camera,
  });
}

Img.Image convertSinglePlaneNv21ToRgbCompute(ConvertNv21ToRgbaDataInput data) {
// The UV data starts after the Y data
  final uvData = data.yData.sublist(data.width * data.height);
  for (int y = 0; y < data.height; y++) {
    for (int x = 0; x < data.width; x++) {
// Get Y value
      final yValue = data.yData[y * data.width + x];

// Get U and V values (interleaved in NV21)
      final uvIndex = (y ~/ 2) * (data.width ~/ 2) + (x ~/ 2);
      final vValue = uvData[uvIndex * 2];
      final uValue = uvData[uvIndex * 2 + 1];

// Convert YUV to RGB
      final r = yValue + 1.402 * (vValue - 128);
      final g = yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
      final b = yValue + 1.772 * (uValue - 128);

// Set the pixel in the RGB image
      data.rgbImage.setPixelRgba(
        x,
        y,
        r.clamp(0, 255).toInt(),
        g.clamp(0, 255).toInt(),
        b.clamp(0, 255).toInt(),
      );
    }
  }
  return data.rgbImage;
}
