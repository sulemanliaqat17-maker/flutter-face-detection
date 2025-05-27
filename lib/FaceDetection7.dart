import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:face_detection_app/FaceEmbedding.dart';
import 'package:face_detection_app/models/FaceData.dart';
import 'package:face_detection_app/utils/colors.dart';
import 'package:face_detection_app/utils/utils.dart';
import 'package:face_detection_app/widgets/customizable_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as Image;
import 'package:opencv_dart/opencv.dart' as cv;
import 'package:path_provider/path_provider.dart';

import '../../providers/api_face_detector_notifier.dart';

class CameraScreen7 extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  final String name;

  CameraScreen7({required this.cameras, required this.name});

  @override
  _CameraScreen7State createState() => _CameraScreen7State();
}

class _CameraScreen7State extends ConsumerState<CameraScreen7> {
  static late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  static bool isProcessing = false;
  int fake = 0;
  int real = 0;
  int iteration = 0;
  bool isStartedStreaming = false;

  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
    ),
  );

  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // _loadORCModel();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.cameras[1],
      ResolutionPreset.low,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _initializeControllerFuture = _controller.initialize();
    await _initializeControllerFuture;

    // Start image stream
  }

  @override
  void dispose() {
    _controller.stopImageStream();
    _controller.dispose();
    // _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // isProcessing = ref.watch(isProcessingProvider);
    // iteration = ref.watch(iterationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Embedding with Camera'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CameraPreview(_controller),
                    // LoadImageWidget(),
                  ],
                ),
                Positioned(
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Fake: ${ref.watch(fakeCountProvider)}"),
                        Text("Real: ${ref.watch(realCountProvider)}"),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: CustomizableTextButton(
                            prefixButtonIcon: null,
                            suffixButtonIcon: null,
                            isFullWidth: true,
                            isOutlined: false,
                            buttonTitle: isStartedStreaming ? "Stop" : "Start",
                            onPressed: () async {
                              if (!isStartedStreaming) {
                                setState(() {
                                  isStartedStreaming = !isStartedStreaming;
                                  isProcessing = false;
                                });
                                await _controller.startImageStream(startImageProcess);
                              } else {
                                setState(() {
                                  isStartedStreaming = !isStartedStreaming;
                                });
                                await _controller.stopImageStream();
                              }
                            },
                            buttonTitleStyle: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            buttonBorderRadius: 10,
                            buttonColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<void> startImageProcess(CameraImage image) async {
    if (FaceEmbedding1.instance.interpreter.isAllocated) {
      if (!isProcessing) {
        setState(() {
          isProcessing = true;
        });
        await _processImage(image, widget.cameras[1]);
      }
    } else {
      print("Not Allocated");
    }
  }

  static InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription cameraDescription) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = cameraDescription;
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format!, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  /*static Future<void> _processImage(IsolatesDataInput message) async {
    if (message.cameraImage != null) {
      InputImage? inputImage =
          _inputImageFromCameraImage(message.cameraImage, message.cameraDescription);
      // ref.read(imageMemoryProvider.notifier).state = inputImage.bytes;
      // ref.read(imageProvider.notifier).state = inputImage;
      try {
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          for (Face face in faces) {
            fake = message.ref.read(fakeCountProvider);
            real = message.ref.read(realCountProvider);
            Map<String, dynamic> data = await _extractFaceData(
                face, inputImage, message.cameraImage, message.ref, message.cameraDescription);
            List<double> faceEmbedding = data["Embedding"];
            bool isFake = data["Fake"];

            message.ref.read(fakeCountProvider.notifier).state = isFake ? (fake + 1) : fake;
            message.ref.read(realCountProvider.notifier).state = isFake ? real : (real + 1);
            // setState(() {
            isProcessing = false;
            iteration = iteration + 1;
            // });
            if (iteration == 10) {
              // final embedding = await _faceEmbedding.getFaceEmbedding(image);
              // Uint8List faceData =
              //     Uint8List.fromList(faceEmbedding.map((e) => (e * 255).toInt()).toList());
              message.ref.refresh(fakeCountProvider);
              message.ref.refresh(realCountProvider);
              final recognizedFace = await _recognizeFace(faceEmbedding, message.ref);

              if (recognizedFace != null) {
                print('Recognized face: ${recognizedFace.name}');
                Fluttertoast.showToast(msg: 'Recognized face: ${recognizedFace.name}');
                Navigator.pop(message.context);
              } else {
                await message.ref
                    .read(databaseProvider)
                    .faceEmbeddingsDao
                    .insertFace("widget.name", faceEmbedding);
                Fluttertoast.showToast(msg: "Registered Face");
                Navigator.pop(message.context);
              }
            }
          }
        } else {
          print("null inputimage");
        }
      } catch (ex, stack) {
        debugPrintStack(stackTrace: stack, label: ex.toString());
      }

      // setState(() {
      //   _embedding = embedding;
      // });
      // print('Face Embedding: $faceData');
    }
  }*/

  Future<void> _processImage(CameraImage? image, CameraDescription camera) async {
    if (image != null) {
      InputImage? inputImage = _inputImageFromCameraImage(image, camera);
      // ref.read(imageMemoryProvider.notifier).state = inputImage.bytes;
      // ref.read(imageProvider.notifier).state = inputImage;
      try {
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          if (faces.isNotEmpty) {
            Face face = faces.first;
            fake = ref.read(fakeCountProvider);
            real = ref.read(realCountProvider);
            Map<String, dynamic> data =
                await _extractFaceData(face, inputImage, image, ref, camera);
            bool isFake = data["Fake"];
            Image.Image croppedImage = data["CroppedImage"] as Image.Image;

            ref.read(fakeCountProvider.notifier).state = isFake ? (fake + 1) : fake;
            ref.read(realCountProvider.notifier).state = isFake ? real : (real + 1);

            if (iteration == 5) {
              List<double> faceEmbedding =
                  await FaceEmbedding1.instance.getFaceEmbedding(croppedImage);
              print("Face Embedding: $faceEmbedding");
              ref.refresh(fakeCountProvider);
              ref.refresh(realCountProvider);
              // _faceEmbedding.disposeModels();
              final recognizedFace = await _recognizeFace(faceEmbedding, ref);
              // await Future.delayed(Duration(seconds: 1));
              if (recognizedFace != null) {
                print('Recognized face: ${recognizedFace.name}');
                Fluttertoast.showToast(msg: 'Welcome ${recognizedFace.name}');
              } else {
                await ref
                    .read(databaseProvider)
                    .faceEmbeddingsDao
                    .insertFace(widget.name, faceEmbedding);
                Fluttertoast.showToast(msg: "Registered Face");
              }
              Navigator.pop(context);
            } else {
              setState(() {
                isProcessing = false;
                iteration = iteration + 1;
              });
            }
          } else {
            setState(() {
              isProcessing = false;
            });
          }
        } else {
          print("null inputimage");
        }
      } catch (ex, stack) {
        debugPrintStack(stackTrace: stack, label: ex.toString());
      }

      // setState(() {
      //   _embedding = embedding;
      // });
      // print('Face Embedding: $faceData');
    }
  }

  static Future<FaceData?> _recognizeFace(List<double> faceData, WidgetRef ref) async {
    double threshold = 0.7;
    final allFaces = await ref.read(databaseProvider).faceEmbeddingsDao.getAllFaces();
    if (allFaces.length != 0) {
      for (final storedFace in allFaces) {
        double similarity = cosineSimilarity(faceData, Utils.parseEmbedding(storedFace.embedding!));
        if (similarity > threshold) {
          return storedFace;
        }
      }
    } else {
      return null;
    }
  }

  static double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
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

  Future<Map<String, dynamic>> _extractFaceData(Face face, InputImage inputImage, CameraImage image,
      WidgetRef ref, CameraDescription camera) async {
    // Step 1: Crop the face from the input image
    Image.Image croppedImage =
        await cropFace1(Crop1DataInput(face: face, cameraImage: image, camera: camera));

    Directory tempDir = await getApplicationCacheDirectory();
    File tempFile = File('${tempDir.path}/temp.png');
    await tempFile.writeAsBytes(Image.encodePng(croppedImage));

    cv.Mat mat = await cv.imreadAsync(tempFile.path);
    cv.Mat imageMat1 = await cropM(CropMDataInput(
        orgImg: mat,
        bbox: [
          face.boundingBox.left.toInt(),
          face.boundingBox.top.toInt(),
          face.boundingBox.width.toInt(),
          face.boundingBox.height.toInt()
        ],
        scale: 2.7,
        outW: 80,
        outH: 80));
    cv.Mat imageMat2 = await cropM(CropMDataInput(
        orgImg: mat,
        bbox: [
          face.boundingBox.left.toInt(),
          face.boundingBox.top.toInt(),
          face.boundingBox.width.toInt(),
          face.boundingBox.height.toInt()
        ],
        scale: 4.0,
        outW: 80,
        outH: 80));
    mat.release();
    mat.dispose();

    List<dynamic> outputModel1 =
        await FaceEmbedding1.instance.getDataFromModel1(/*bitmapImage1,*/ imageMat1);
    imageMat1.release();
    imageMat1.dispose();
    List<double> inputModel1 = await compute(softmax, (outputModel1 as List<double>));
    print("Model1 Output: $inputModel1");

    List<dynamic> outputModel2 =
        await FaceEmbedding1.instance.getDataFromModel2(/*bitmapImage1,*/ imageMat2);
    imageMat2.release();
    imageMat2.dispose();
    List<double> inputModel2 = await compute(softmax, (outputModel2 as List<double>));
    print("Model2 Output: $inputModel2");

    final prediction = List<double>.filled(3, 0.0);
    for (int i = 0; i < prediction.length; i++) {
      prediction[i] += inputModel1[i];
      prediction[i] += inputModel2[i];
    }

    print("Prediction: $prediction");

    var label = prediction.indexOf(prediction.reduce((a, b) => a > b ? a : b));

    bool isReal = (label == 1);
    double score = prediction[label] / 2;

    bool isFake = isReal == false || (isReal == true && score <= 0.7);

    print("Label: $label");
    print("IsReal: $isReal");
    print("Score: $score");
    print("Is Fake: $isFake");
    Map<String, dynamic> returnData = {
      "CroppedImage": croppedImage,
      "Fake": isFake,
    };
    return returnData;
  }

  Future<cv.Mat> cropM(CropMDataInput data) async {
    int srcH = data.orgImg.rows;
    int srcW = data.orgImg.cols;

    List<int> newBox = await compute(
        getNewBox, GetNewBoxDataInput(srcW: srcW, srcH: srcH, bbox: data.bbox, scale: data.scale));

    // Crop image
    int cropWidth = newBox[2] - newBox[0];
    int cropHeight = newBox[3] - newBox[1];

    // Create a Rect for the crop area
    // cv.Rect rect = cv.Rect(newBox[0], newBox[1], cropWidth, cropHeight);

    // orgImg.at(i0, i1)
    // Crop the image

    cv.Mat croppedImg = await computeCropM(ComputeCropMDataInput(
        orgImg: data.orgImg, newBox: newBox, cropWidth: cropWidth, cropHeight: cropHeight));

    // Resize to target dimensions
    cv.Mat dstImg = cv.Mat.empty();
    await cv.resizeAsync(
      croppedImg,
      (data.outW, data.outH),
      dst: dstImg,
    );

    // Manual cleanup (recommended for memory management)
    // croppedImg.release(); // Uncomment if needed
    croppedImg.release();

    return dstImg;
  }

  Future<cv.Mat> computeCropM(ComputeCropMDataInput data) async {
    cv.Mat croppedImg = cv.Mat.zeros(data.cropHeight, data.cropWidth, data.orgImg.type);
    for (var y = 0; y < data.cropHeight; y++) {
      for (var x = 0; x < data.cropWidth; x++) {
        int srcX = x + data.newBox[0];
        int srcY = y + data.newBox[1];
        cv.Vec3b pixel = data.orgImg.at<cv.Vec3b>(srcY, srcX);
        croppedImg.set(x, y, pixel);
        // croppedImg.at<cv.Vec3b>(y, x)/* = pixel*/;
      }
    }
    return croppedImg;
  }

  static Future<Image.Image> crop(
      Image.Image orgImg, List<int> bbox, double scale, int outW, int outH) async {
    // Get the dimensions of the original image
    final srcH = orgImg.height;
    final srcW = orgImg.width;

    // Calculate the new bounding box coordinates
    List<int> newBox = await compute(
        getNewBox, GetNewBoxDataInput(srcW: srcW, srcH: srcH, bbox: bbox, scale: scale));

    // [leftTopX, leftTopY, rightBottomX, rightBottomY]
    // Crop the image using the bounding box
    final croppedImg = Image.copyCrop(
      orgImg,
      newBox[0],
      newBox[1],
      newBox[2] - newBox[0],
      newBox[3] - newBox[1],
    );

    // Resize the cropped image to the output size
    final dstImg = Image.copyResize(
      croppedImg,
      width: outW,
      height: outH,
      interpolation: Image.Interpolation.cubic, // Use cubic interpolation for better quality
    );

    return dstImg;
  }

  Future<Image.Image> cropFace1(Crop1DataInput data) async {
    // Get image dimensions
    final width = data.cameraImage.width;
    final height = data.cameraImage.height;

    Image.Image img = Image.Image(width, height);
    if (data.cameraImage.format.group == ImageFormatGroup.yuv420) {
      // Convert YUV to RGB
      img = _convertYuv420ToRgb(data.cameraImage);
    } else if (data.cameraImage.format.group == ImageFormatGroup.nv21) {
      final orientation = WidgetsBinding.instance.window.physicalSize.aspectRatio > 1
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.portraitUp;
      img = await convertSinglePlaneNv21ToRgb(data.cameraImage, data.camera, orientation);
    } else if (data.cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // Convert BGRA to Image
      img = Image.Image.fromBytes(
        width,
        height,
        data.cameraImage.planes[0].bytes,
        format: Image.Format.bgra,
      );
    } else {
      throw Exception('Unsupported image format: ${data.cameraImage.format.group}');
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
    return Image.copyCrop(img, left, top, fWidth, fHeight);
  }

  static InputImageRotation _calculateRotation(
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
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }

    // Map rotation compensation to InputImageRotation
    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  static Future<Image.Image> convertSinglePlaneNv21ToRgb(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    // Ensure the image has exactly 1 plane
    if (image.planes.length != 1) {
      throw Exception('Expected 1 plane for single-plane NV21, but found ${image.planes.length}');
    }

    final plane = image.planes[0]; // Single plane containing Y and interleaved UV data
    final width = image.width;
    final height = image.height;

    // Create an empty RGB image
    Image.Image rgbImage = Image.Image(width, height);

    // The Y data occupies the first part of the plane
    final yData = plane.bytes;

    rgbImage = await compute(convertSinglePlaneNv21ToRgbCompute,
        ConvertNv21ToRgbaDataInput(height: height, width: width, yData: yData, rgbImage: rgbImage));

    // Calculate the rotation based on sensor orientation, device orientation, and lens direction
    final rotation = _calculateRotation(camera, deviceOrientation);

    // Rotate the image based on the calculated rotation
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        rgbImage = Image.copyRotate(rgbImage, 90);
        break;
      case InputImageRotation.rotation270deg:
        rgbImage = Image.copyRotate(rgbImage, -90);
        break;
      case InputImageRotation.rotation180deg:
        rgbImage = Image.copyRotate(rgbImage, 180);
        break;
      default:
        // No rotation needed
        break;
    }

    return rgbImage;
  }

  static Image.Image _convertYuv420ToRgb(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final rgbImage = Image.Image(image.width, image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final yValue = yPlane.bytes[y * yPlane.bytesPerRow + x];
        final uValue = uPlane.bytes[(y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2)];
        final vValue = vPlane.bytes[(y ~/ 2) * vPlane.bytesPerRow + (x ~/ 2)];

        // Convert YUV to RGB
        final r = yValue + 1.402 * (vValue - 128);
        final g = yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
        final b = yValue + 1.772 * (uValue - 128);

        // Set the pixel in the Image object
        rgbImage.setPixelRgba(
            x, y, r.clamp(0, 255).toInt(), g.clamp(0, 255).toInt(), b.clamp(0, 255).toInt());
      }
    }

    return rgbImage;
  }
}

/*InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription cameraDescription) {
  if (_controller == null) return null;
  Map orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  // get image rotation
  // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
  // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
  // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
  final camera = cameraDescription;
  final sensorOrientation = camera.sensorOrientation;
  // print(
  //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
  InputImageRotation? rotation;
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    var rotationCompensation = orientations[_controller!.value.deviceOrientation];
    if (rotationCompensation == null) return null;
    if (camera.lensDirection == CameraLensDirection.front) {
      // front-facing
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      // back-facing
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    // print('rotationCompensation: $rotationCompensation');
  }
  if (rotation == null) return null;
  // print('final rotation: $rotation');

  // get image format
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  // validate format depending on platform
  // only supported formats:
  // * nv21 for Android
  // * bgra8888 for iOS
  if (format == null ||
      (Platform.isAndroid && format != InputImageFormat.nv21) ||
      (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

  // since format is constraint to nv21 or bgra8888, both only have one plane
  if (image.planes.length != 1) return null;
  final plane = image.planes.first;
  // compose InputImage using bytes
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation, // used only in Android
      format: format!, // used only in iOS
      bytesPerRow: plane.bytesPerRow, // used only in iOS
    ),
  );
}*/

List<double> softmax(List<double> x) {
// Find the maximum value in the list (for numerical stability)
  print(x);
  final max = x.reduce((a, b) => a > b ? a : b);

// Compute the exponentials and their sum
  final expValues = x.map((value) => exp(value - max)).toList();
  final sumExpValues = expValues.reduce((a, b) => a + b);

// Compute the softmax by dividing each exponential value by the sum of exponentials
  return expValues.map((value) => value / sumExpValues).toList();
}

Image.Image convertSinglePlaneNv21ToRgbCompute(ConvertNv21ToRgbaDataInput data) {
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

List<int> getNewBox(GetNewBoxDataInput data) {
  final x = data.bbox[0];
  final y = data.bbox[1];
  final boxW = data.bbox[2];
  final boxH = data.bbox[3];

  // Ensure the scale does not exceed the maximum allowed scale
  var newScale = data.scale.clamp(0.0, (data.srcH - 1) / boxH);
  newScale = newScale.clamp(0.0, (data.srcW - 1) / boxW);

  // Calculate the new width and height
  final newWidth = boxW * newScale;
  final newHeight = boxH * newScale;

  // Calculate the center of the bounding box
  final centerX = boxW / 2.0 + x;
  final centerY = boxH / 2.0 + y;

  // Calculate the new bounding box coordinates
  var leftTopX = centerX - newWidth / 2;
  var leftTopY = centerY - newHeight / 2;
  var rightBottomX = centerX + newWidth / 2;
  var rightBottomY = centerY + newHeight / 2;

  // Adjust coordinates if they go out of bounds
  if (leftTopX < 0) {
    rightBottomX -= leftTopX;
    leftTopX = 0.0;
  }
  if (leftTopY < 0) {
    rightBottomY -= leftTopY;
    leftTopY = 0.0;
  }
  if (rightBottomX > data.srcW - 1) {
    leftTopX -= rightBottomX - data.srcW + 1;
    rightBottomX = (data.srcW - 1).toDouble();
  }
  if (rightBottomY > data.srcH - 1) {
    leftTopY -= rightBottomY - data.srcH + 1;
    rightBottomY = (data.srcH - 1).toDouble();
  }

  // Return the new bounding box coordinates as integers
  return [
    leftTopX.toInt(),
    leftTopY.toInt(),
    rightBottomX.toInt(),
    rightBottomY.toInt(),
  ];
}

/*class InputImageFromCameraImageDataInput {
  final dynamic raw;
  final dynamic planes;
  final double width;
  final double height;
  final CameraDescription cameraDescription;
}*/

class IsolatesDataInput {
  final SendPort sendPort;
  final CameraImage cameraImage;
  final WidgetRef ref;
  final BuildContext context;
  final CameraDescription cameraDescription;

  IsolatesDataInput(
      {required this.sendPort,
      required this.cameraImage,
      required this.ref,
      required this.context,
      required this.cameraDescription});
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

class ConvertNv21ToRgbaDataInput {
  // final SendPort sendPort;
  final int height;
  final int width;
  final Uint8List yData;
  final Image.Image rgbImage;

  ConvertNv21ToRgbaDataInput({
    // required this.sendPort,
    required this.height,
    required this.width,
    required this.yData,
    required this.rgbImage,
  });
}

class ComputeCropMDataInput {
  // final SendPort sendPort;
  final cv.Mat orgImg;
  final List<int> newBox;
  final int cropWidth;
  final int cropHeight;

  ComputeCropMDataInput({
    // required this.sendPort,
    required this.orgImg,
    required this.newBox,
    required this.cropWidth,
    required this.cropHeight,
  });
}

class GetNewBoxDataInput {
  // final SendPort sendPort;
  final int srcW;
  final int srcH;
  final List<int> bbox;
  final double scale;

  GetNewBoxDataInput({
    // required this.sendPort,
    required this.srcW,
    required this.srcH,
    required this.bbox,
    required this.scale,
  });
}

class CropMDataInput {
  final cv.Mat orgImg;
  final List<int> bbox;
  final double scale;
  final int outW;
  final int outH;

  CropMDataInput({
    required this.orgImg,
    required this.bbox,
    required this.scale,
    required this.outW,
    required this.outH,
  });
}
