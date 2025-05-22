import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:face_detection_app/FaceEmbedding.dart';
import 'package:face_detection_app/models/FaceData.dart';
import 'package:face_detection_app/providers/api_face_detector_notifier.dart';
import 'package:face_detection_app/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as Image;
import 'package:opencv_dart/opencv.dart' as cv;
import 'package:path_provider/path_provider.dart';

class CameraScreen6 extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  final String name;

  CameraScreen6({required this.cameras, required this.name});

  @override
  _CameraScreen6State createState() => _CameraScreen6State();
}

class _CameraScreen6State extends ConsumerState<CameraScreen6> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool isProcessing = false;
  int fake = 0;
  int real = 0;
  int iteration = 0;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
    ),
  );

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeCamera();
    });
    // _loadORCModel();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.cameras[1],
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _initializeControllerFuture = _controller.initialize();
    await _initializeControllerFuture;

    // Start image stream
    _controller.startImageStream((CameraImage image) async {
      if (FaceEmbedding.instance.interpreter.isAllocated) {
        if (!isProcessing) {
          setState(() {
            isProcessing = true;
          });
          // final convertedImage = _convertCameraImage(image);
          // ref.read(imageMemoryProvider.notifier).state = convertedImage.getBytes();
          await _processImage(image);
          // final embedding = await _faceEmbedding.getFaceEmbedding(convertedImage);
          // print('Face Embedding: $embedding');
          // setState(() {
          //   isProcessing = false;
          // });

          // final inputData = await _preprocessORCImage(convertOCRCameraImageToImage(image));
          // await _runOCRInference(inputData);
          // _postProcessORCOutput(outputs);
        }
      } else {
        print("Not Allocated");
      }
    });
  }

  InputImage convertCameraImageToInputImage(CameraImage cameraImage) {
    // Ensure the format is BGRA
    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // Get the raw bytes from the first plane
      final plane = cameraImage.planes[0];
      final bytes = plane.bytes;

      // Create InputImageMetadata
      final inputImageData = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: InputImageRotation.rotation0deg, // Adjust rotation if needed
        format: InputImageFormat.bgra8888, // Match the format of the CameraImage
        bytesPerRow: plane.bytesPerRow, // Bytes per row of the image
      );

      // Create InputImage from bytes
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } else if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      // Convert YUV to NV21 format
      final yBuffer = yPlane.bytes;
      final uBuffer = uPlane.bytes;
      final vBuffer = vPlane.bytes;

      final ySize = yBuffer.length;
      final uvSize = uBuffer.length + vBuffer.length;

      final nv21Buffer = Uint8List(ySize + uvSize);

      // Copy Y plane
      nv21Buffer.setRange(0, ySize, yBuffer);

      // Interleave U and V planes
      for (int i = 0; i < uvSize ~/ 2; i++) {
        nv21Buffer[ySize + 2 * i] = vBuffer[i];
        nv21Buffer[ySize + 2 * i + 1] = uBuffer[i];
      }

      // Create InputImageMetadata
      final inputImageData = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: InputImageRotation.rotation0deg, // Adjust rotation if needed
        format: InputImageFormat.nv21, // Use NV21 format for YUV
        bytesPerRow: yPlane.bytesPerRow, // Bytes per row of the Y plane
      );

      // Create InputImage from bytes
      return InputImage.fromBytes(
        bytes: nv21Buffer,
        metadata: inputImageData,
      );
    } else {
      throw Exception('Unsupported image format: ${cameraImage.format.group}');
    }
  }

  Image.Image convertOCRCameraImageToImage(CameraImage cameraImage) {
    // Ensure the format is NV21
    if (cameraImage.format.group != ImageFormatGroup.nv21) {
      throw Exception('Unsupported image format: ${cameraImage.format.group}');
    }

    // Get the single plane
    final plane = cameraImage.planes[0];
    final bytes = plane.bytes;

    // Create an empty Image object
    final image = Image.Image(cameraImage.width, cameraImage.height);

    // Extract Y and VU data from the single plane
    final yPlane = bytes.sublist(0, cameraImage.width * cameraImage.height);
    final vuPlane = bytes.sublist(cameraImage.width * cameraImage.height);

    // Convert NV21 to RGB
    for (var y = 0; y < cameraImage.height; y++) {
      for (var x = 0; x < cameraImage.width; x++) {
        // Get Y (luminance) value
        final yIndex = y * cameraImage.width + x;
        final yValue = yPlane[yIndex];

        // Get U and V (chrominance) values
        final uvIndex = (y ~/ 2) * (cameraImage.width ~/ 2) + (x ~/ 2);
        final vValue = vuPlane[uvIndex * 2];
        final uValue = vuPlane[uvIndex * 2 + 1];

        // Convert YUV to RGB
        final rgb = yuv2rgb(yValue, uValue, vValue);

        // Set the pixel color in the Image object
        image.setPixelRgba(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }

    return image;
  }

  List<int> yuv2rgb(int y, int u, int v) {
    // Convert YUV to RGB using the standard formula
    final c = y - 16;
    final d = u - 128;
    final e = v - 128;

    final r = (298 * c + 409 * e + 128) ~/ 256;
    final g = (298 * c - 100 * d - 208 * e + 128) ~/ 256;
    final b = (298 * c + 516 * d + 128) ~/ 256;

    // Clamp the values to the range [0, 255]
    return [
      r.clamp(0, 255),
      g.clamp(0, 255),
      b.clamp(0, 255),
    ];
  }

  Image.Image convertCameraImageToImage(CameraImage cameraImage) {
    // Ensure the format is BGRA
    if (cameraImage.format.group != ImageFormatGroup.bgra8888) {
      throw Exception('Unsupported image format: ${cameraImage.format.group}');
    }

    // Get the raw bytes from the first plane
    final plane = cameraImage.planes[0];
    final bytes = plane.bytes;

    // Create an Image object from the raw bytes
    final image = Image.Image.fromBytes(
      cameraImage.width,
      cameraImage.height,
      bytes,
      format: Image.Format.bgra, // Match the format of the CameraImage
    );

    return image;
  }

  Image.Image _convertCameraImage(CameraImage image) {
    // Convert CameraImage to Image object

    final img = Image.Image.fromBytes(
      image.width,
      image.height,
      image.planes[0].bytes,
      format: Image.Format.bgra, // Adjust format based on CameraImage format
    );
    return img;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                )
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<List<double>> _preprocessORCImage(Image.Image image) async {
    // Resize the image to 640x640
    final resizedImage = Image.copyResize(image, width: 640, height: 640);

    // Normalize pixel values to [0, 1]
    final inputData = Float32List(1 * 3 * 640 * 640);
    for (var y = 0; y < 640; y++) {
      for (var x = 0; x < 640; x++) {
        final pixel = resizedImage.getPixel(x, y);
        inputData[y * 640 + x] = Image.getRed(pixel) / 255.0; // Red channel
        inputData[640 * 640 + y * 640 + x] = Image.getGreen(pixel) / 255.0; // Green channel
        inputData[2 * 640 * 640 + y * 640 + x] = Image.getBlue(pixel) / 255.0; // Blue channel
      }
    }

    return inputData;
  }

  InputImage convertImageToInputImage(Image.Image image) {
    // Convert Image to Uint8List (raw image bytes)
    Uint8List imageBytes = Uint8List.fromList(Image.encodePng(image));

    // Get image metadata
    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg, // Adjust rotation if needed
      format: InputImageFormat.bgra8888, // Adjust format if needed
      bytesPerRow: image.width * 4, // Assuming 4 bytes per pixel (RGBA)
    );

    // Create InputImage
    return InputImage.fromBytes(
      bytes: imageBytes,
      metadata: inputImageData,
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final camera = widget.cameras[1];
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

  Future<void> _processImage(CameraImage? image) async {
    if (image != null) {
      InputImage? inputImage = _inputImageFromCameraImage(image);
      // ref.read(imageMemoryProvider.notifier).state = inputImage.bytes;
      // ref.read(imageProvider.notifier).state = inputImage;
      try {
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          for (Face face in faces) {
            fake = ref.read(fakeCountProvider);
            real = ref.read(realCountProvider);
            Map<String, dynamic> data = await _extractFaceData(face, inputImage, image);
            List<double> faceEmbedding = data["Embedding"];
            bool isFake = data["Fake"];

            ref.read(fakeCountProvider.notifier).state = isFake ? (fake + 1) : fake;
            ref.read(realCountProvider.notifier).state = isFake ? real : (real + 1);

            if (iteration == 10) {
              // final embedding = await _faceEmbedding.getFaceEmbedding(image);
              // Uint8List faceData =
              //     Uint8List.fromList(faceEmbedding.map((e) => (e * 255).toInt()).toList());
              ref.refresh(fakeCountProvider);
              ref.refresh(realCountProvider);
              final recognizedFace = await _recognizeFace(faceEmbedding);

              if (recognizedFace != null) {
                print('Recognized face: ${recognizedFace.name}');
                Fluttertoast.showToast(msg: 'Recognized face: ${recognizedFace.name}');
                Navigator.pop(context);
              } else {
                await ref
                    .read(databaseProvider)
                    .faceEmbeddingsDao
                    .insertFace(widget.name, faceEmbedding);
                Fluttertoast.showToast(msg: "Registered Face");
                Navigator.pop(context);
              }
            } else {
              setState(() {
                isProcessing = false;
                iteration = iteration + 1;
              });
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
  }

  Future<FaceData?> _recognizeFace(List<double> faceData) async {
    double threshold = 0.7;
    final allFaces = await ref.read(databaseProvider).faceEmbeddingsDao.getAllFaces();
    for (final storedFace in allFaces) {
      double similarity = cosineSimilarity(faceData, Utils.parseEmbedding(storedFace.embedding!));
      if (similarity > threshold) {
        return storedFace;
      }
    }
    return null;
  }

  //Euclidean Distance
  /*bool _compareFaces(Uint8List faceData1, Uint8List faceData2) {
    // Ensure both face data have the same length
    if (faceData1.length != faceData2.length) {
      return false;
    }

    double sum = 0;
    for (int i = 0; i < faceData1.length; i++) {
      final diff = faceData1[i] - faceData2[i];
      sum += diff * diff;
    }

    final distance = sqrt(sum); // Euclidean distance

    // Define a threshold for face similarity
    const threshold = 0.6; // Adjust this value based on your requirements
    return distance < threshold;
  }*/

  bool _compareFaces(Uint8List faceData1, Uint8List faceData2) {
    // Ensure both face data have the same length
    if (faceData1.length != faceData2.length) {
      return false;
    }

    // Convert Uint8List to List<double>
    final embedding1 = faceData1.map((value) => value.toDouble()).toList();
    final embedding2 = faceData2.map((value) => value.toDouble()).toList();

    // Normalize the embeddings (L2 normalization)
    final norm1 = sqrt(embedding1.map((value) => value * value).reduce((a, b) => a + b));
    final norm2 = sqrt(embedding2.map((value) => value * value).reduce((a, b) => a + b));

    final normalizedEmbedding1 = embedding1.map((value) => value / norm1).toList();
    final normalizedEmbedding2 = embedding2.map((value) => value / norm2).toList();

    // Calculate cosine similarity
    double dotProduct = 0;
    for (int i = 0; i < normalizedEmbedding1.length; i++) {
      dotProduct += normalizedEmbedding1[i] * normalizedEmbedding2[i];
    }

    final similarity = dotProduct; // Cosine similarity ranges from -1 to 1

    // Define a threshold for face similarity
    const threshold = 0.7; // Adjust this value based on your requirements
    print("Similarity: $similarity");
    return similarity > threshold;
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

  Future<Map<String, dynamic>> _extractFaceData(
      Face face, InputImage inputImage, CameraImage image) async {
    // Step 1: Crop the face from the input image
    // final croppedImage = _cropFace(face, inputImage);
    final croppedImage = _cropFace1(face, image);
    ref.read(imageMemoryProvider.notifier).state = Image.encodePng(croppedImage) as Uint8List;
    // Step 2: Preprocess the cropped image

    // Convert the resized image to Uint8List (bitmap-like format)
    final bitmapImage1 = Uint8List.fromList(Image.encodePng(croppedImage));
    final bitmapImage2 = Uint8List.fromList(Image.encodePng(croppedImage));
    // Bitmap b1 = Bitmap.fromHeadful(resizedImg1.width, resizedImg1.height, bitmapImage1);
    // Bitmap b2 = Bitmap.fromHeadful(resizedImg2.width, resizedImg2.height, bitmapImage2);
    final tempDir = await getApplicationCacheDirectory();
    final tempFile = File('${tempDir.path}/temp.png');
    await tempFile.writeAsBytes(Image.encodePng(croppedImage));
    final mat = await cv.imread(tempFile.path);
    // final tempFile1 = File('${tempDir.path}/temp1.png');
    // await tempFile1.writeAsBytes(Image.encodePng(resizedImg2));
    // final mat1 = await cv.imread(tempFile1.path);
    cv.Mat imageMat1 = cropM(
        mat,
        [
          face.boundingBox.left.toInt(),
          face.boundingBox.top.toInt(),
          face.boundingBox.width.toInt(),
          face.boundingBox.height.toInt()
        ],
        2.7,
        80,
        80);
    cv.Mat imageMat2 = cropM(
        mat,
        [
          face.boundingBox.left.toInt(),
          face.boundingBox.top.toInt(),
          face.boundingBox.width.toInt(),
          face.boundingBox.height.toInt()
        ],
        4.0,
        80,
        80);

    final inputModel1 =
        softmax(await FaceEmbedding.instance.getDataFromModel1(bitmapImage1, imageMat1));

    print("Model1 Output: $inputModel1");

    final inputModel2 =
        softmax(await FaceEmbedding.instance.getDataFromModel2(bitmapImage2, imageMat2));
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
    final input = await FaceEmbedding.instance.getFaceEmbedding(croppedImage);
    print("Face Embedding: $input");
    Map<String, dynamic> returnData = {
      "Embedding": input,
      "Fake": isFake,
    };
    return returnData;
  }

  cv.Mat cropM(cv.Mat orgImg, List<int> bbox, double scale, int outW, int outH) {
    final srcH = orgImg.rows;
    final srcW = orgImg.cols;

    List<int> newBox = getNewBox(srcW, srcW, bbox, scale);

    // Crop image
    final cropWidth = newBox[2] - newBox[0];
    final cropHeight = newBox[3] - newBox[1];

    // Create a Rect for the crop area
    final rect = cv.Rect(newBox[0], newBox[1], cropWidth, cropHeight);

    // orgImg.at(i0, i1)
    // Crop the image
    cv.Mat croppedImg = cv.Mat.zeros(cropHeight, cropWidth, orgImg.type);
    for (var y = 0; y < cropHeight; y++) {
      for (var x = 0; x < cropWidth; x++) {
        final srcX = x + newBox[0];
        final srcY = y + newBox[1];
        final pixel = orgImg.at<cv.Vec3b>(srcY, srcX);
        croppedImg.set(x, y, pixel);
        // croppedImg.at<cv.Vec3b>(y, x)/* = pixel*/;
      }
    }

    // Resize to target dimensions
    final dstImg = cv.Mat.empty();
    cv.resize(
      croppedImg,
      (outW, outH),
      dst: dstImg,
    );

    // Manual cleanup (recommended for memory management)
    // croppedImg.release(); // Uncomment if needed

    return dstImg;
  }

  Image.Image crop(Image.Image orgImg, List<int> bbox, double scale, int outW, int outH) {
    // Get the dimensions of the original image
    final srcH = orgImg.height;
    final srcW = orgImg.width;

    // Calculate the new bounding box coordinates
    final List<int> newBox = getNewBox(srcW, srcH, bbox, scale);

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

  List<int> getNewBox(int srcW, int srcH, List<int> bbox, double scale) {
    final x = bbox[0];
    final y = bbox[1];
    final boxW = bbox[2];
    final boxH = bbox[3];

    // Ensure the scale does not exceed the maximum allowed scale
    var newScale = scale.clamp(0.0, (srcH - 1) / boxH);
    newScale = newScale.clamp(0.0, (srcW - 1) / boxW);

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
    if (rightBottomX > srcW - 1) {
      leftTopX -= rightBottomX - srcW + 1;
      rightBottomX = (srcW - 1).toDouble();
    }
    if (rightBottomY > srcH - 1) {
      leftTopY -= rightBottomY - srcH + 1;
      rightBottomY = (srcH - 1).toDouble();
    }

    // Return the new bounding box coordinates as integers
    return [
      leftTopX.toInt(),
      leftTopY.toInt(),
      rightBottomX.toInt(),
      rightBottomY.toInt(),
    ];
  }

  Uint8List convertInputImageToDisplayableImage(InputImage inputImage) {
    if (inputImage.metadata?.format == InputImageFormat.bgra8888) {
      // For BGRA format
      final image = Image.Image.fromBytes(
        inputImage.metadata?.size.width.toInt() ?? 0,
        inputImage.metadata?.size.height.toInt() ?? 0,
        inputImage.bytes!,
        format: Image.Format.bgra, // Specify the input format
      );

      // Encode the image as PNG
      return Image.encodePng(image) as Uint8List;
    } else if (inputImage.metadata?.format == InputImageFormat.nv21) {
      // For NV21 format (YUV)

      final image = Image.Image.fromBytes(
        inputImage.metadata?.size.width.toInt() ?? 0,
        inputImage.metadata?.size.height.toInt() ?? 0,
        inputImage.bytes!,
        format: Image.Format.bgra, // Specify the input format
      );

      // Encode the image as PNG
      return Image.encodePng(image) as Uint8List;
    } else {
      throw Exception('Unsupported image format: ${inputImage.metadata?.format}');
    }
  }

  Image.Image _cropFace1(Face face, CameraImage cameraImage) {
    // Get image dimensions
    final width = cameraImage.width;
    final height = cameraImage.height;

    Image.Image img;
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      // Convert YUV to RGB
      img = _convertYuv420ToRgb(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
      final orientation = WidgetsBinding.instance.window.physicalSize.aspectRatio > 1
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.portraitUp;
      img = convertSinglePlaneNv21ToRgb(cameraImage, widget.cameras[1], orientation);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // Convert BGRA to Image
      img = Image.Image.fromBytes(
        width,
        height,
        cameraImage.planes[0].bytes,
        format: Image.Format.bgra,
      );
    } else {
      throw Exception('Unsupported image format: ${cameraImage.format.group}');
    }

    // Get face bounding box
    final rect = face.boundingBox;
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

  Image.Image _cropFace(Face face, InputImage inputImage) {
    final metadata = inputImage.metadata!;
    final width = metadata.size.height;
    final height = metadata.size.width;

    Image.Image img;
    if (metadata.format == InputImageFormat.nv21 ||
        metadata.format == InputImageFormat.yuv_420_888) {
      // Convert YUV to RGB
      final rgbBuffer = yuv420ToRgb(inputImage.bytes!, width.toInt(), height.toInt(), metadata);
      img = rgbToImage(rgbBuffer, width.toInt(), height.toInt());
    } else {
      // Assume the image is already in a standard format (e.g., JPEG, PNG)
      img = Image.decodeImage(inputImage.bytes!)!;
    }

    // **Apply Rotation Fix** (based on metadata.rotation)
    if (metadata.rotation == InputImageRotation.rotation90deg) {
      img = Image.copyRotate(img, 90);
    } else if (metadata.rotation == InputImageRotation.rotation270deg) {
      img = Image.copyRotate(img, -90);
    } else if (metadata.rotation == InputImageRotation.rotation180deg) {
      img = Image.copyRotate(img, 180);
    }

    // Get face bounding box
    final rect = face.boundingBox;
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
    if (left < 0 || top < 0 || right > width || bottom > height) {
      print('Error: Bounding box is outside image dimensions!');
      return img; // Return the original image if the bounding box is invalid
    }

    // Crop the face
    return Image.copyCrop(img, left, top, fWidth, fHeight);
  }

  /*Image.Image _cropFace(Face face, InputImage inputImage) {
    final metadata = inputImage.metadata!;
    final width = metadata.size.width;
    final height = metadata.size.height;

    Image.Image img;
    if (metadata.format == InputImageFormat.nv21 ||
        metadata.format == InputImageFormat.yuv_420_888) {
      // Convert YUV to RGB
      final rgbBuffer = yuv420ToRgb(inputImage.bytes!, width.toInt(), height.toInt(), metadata);
      img = rgbToImage(rgbBuffer, width.toInt(), height.toInt());
    } else {
      // Assume the image is already in a standard format (e.g., JPEG, PNG)
      img = Image.decodeImage(inputImage.bytes!)!;
    }

    // **Apply Rotation Fix** (based on metadata.rotation)
    if (metadata.rotation == InputImageRotation.rotation90deg) {
      img = Image.copyRotate(img, 90);
    } else if (metadata.rotation == InputImageRotation.rotation270deg) {
      img = Image.copyRotate(img, -90);
    } else if (metadata.rotation == InputImageRotation.rotation180deg) {
      img = Image.copyRotate(img, 180);
    }

    // Get the translated bounding box coordinates
    final left = translateX(
      face.boundingBox.left,
      Size(392, 698),
      Size(img.width.toDouble(), img.height.toDouble()),
      metadata.rotation,
      CameraLensDirection.front,
    );
    final top = translateY(
      face.boundingBox.top,
      Size(392, 698),
      Size(img.width.toDouble(), img.height.toDouble()),
      metadata.rotation,
      CameraLensDirection.front,
    );
    final right = translateX(
      face.boundingBox.right,
      Size(392, 698),
      Size(img.width.toDouble(), img.height.toDouble()),
      metadata.rotation,
      CameraLensDirection.front,
    );
    final bottom = translateY(
      face.boundingBox.bottom,
      Size(392, 698),
      Size(img.width.toDouble(), img.height.toDouble()),
      metadata.rotation,
      CameraLensDirection.front,
    );

    // Calculate width and height of the bounding box
    final fWidth = (right - left).toInt().abs();
    final fHeight = (bottom - top).toInt().abs();

    // Debug the bounding box values
    print('Translated bounding box: left=$left, top=$top, width=$fWidth, height=$fHeight');

    // Ensure the bounding box is within image dimensions
    if (left < 0 || top < 0 || left + fWidth > img.width || top + fHeight > img.height) {
      print('Error: Bounding box is outside image dimensions!');
      return img; // Return the original image if the bounding box is invalid
    }

    // Crop the face
    return Image.copyCrop(img, left.toInt(), top.toInt(), fWidth, fHeight);
  }*/

  /*Image.Image _cropFace(Face face, InputImage inputImage) {
    final metadata = inputImage.metadata!;
    final width = metadata.size.width;
    final height = metadata.size.height;

    Image.Image img;
    if (metadata.format == InputImageFormat.nv21 ||
        metadata.format == InputImageFormat.yuv_420_888) {
      // Convert YUV to RGB
      final rgbBuffer = yuv420ToRgb(inputImage.bytes!, width.toInt(), height.toInt(), metadata);
      img = rgbToImage(rgbBuffer, width.toInt(), height.toInt());
    } else {
      // Assume the image is already in a standard format (e.g., JPEG, PNG)
      img = Image.decodeImage(inputImage.bytes!)!;
    }
    // **Apply Rotation Fix** (based on metadata.rotation)
    if (metadata.rotation == InputImageRotation.rotation90deg) {
      img = Image.copyRotate(img, 90);
    } else if (metadata.rotation == InputImageRotation.rotation270deg) {
      img = Image.copyRotate(img, -90);
    } else if (metadata.rotation == InputImageRotation.rotation180deg) {
      img = Image.copyRotate(img, 180);
    }

    // Get face bounding box
    final rect = face.boundingBox;
    final left = rect.left.toInt();
    final top = rect.top.toInt();
    final fWidth = rect.width.toInt();
    final fHeight = rect.height.toInt();

    // Debug the bounding box values
    print('Bounding box: left=$left, top=$top, width=$fWidth, height=$fHeight');

    // Ensure the bounding box is within image dimensions
    if (left < 0 || top < 0 || left + fWidth > width || top + fHeight > height) {
      print('Error: Bounding box is outside image dimensions!');
      return img; // Return the original image if the bounding box is invalid
    }

    // Crop the face
    return Image.copyCrop(img, left, top, fWidth, fHeight);
  }*/

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
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }

    // Map rotation compensation to InputImageRotation
    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  Image.Image convertSinglePlaneNv21ToRgb(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
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

    // The UV data starts after the Y data
    final uvData = yData.sublist(width * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Get Y value
        final yValue = yData[y * width + x];

        // Get U and V values (interleaved in NV21)
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
        final vValue = uvData[uvIndex * 2];
        final uValue = uvData[uvIndex * 2 + 1];

        // Convert YUV to RGB
        final r = yValue + 1.402 * (vValue - 128);
        final g = yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
        final b = yValue + 1.772 * (uValue - 128);

        // Set the pixel in the RGB image
        rgbImage.setPixelRgba(
          x,
          y,
          r.clamp(0, 255).toInt(),
          g.clamp(0, 255).toInt(),
          b.clamp(0, 255).toInt(),
        );
      }
    }

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

  Image.Image _convertYuv420ToRgb(CameraImage image) {
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

  Uint8List yuv420ToRgb(Uint8List yuvBytes, int width, int height, InputImageMetadata metadata) {
    final rgbBuffer = Uint8List((width * height * 3).toInt());

    final yPlane = yuvBytes;
    final uvPlane = yuvBytes.sublist(width * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        final yValue = yPlane[yIndex];
        final uValue = uvPlane[uvIndex * 2];
        final vValue = uvPlane[uvIndex * 2 + 1];

        // Convert YUV to RGB
        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        final rgbIndex = (y * width + x) * 3;
        rgbBuffer[rgbIndex] = r;
        rgbBuffer[rgbIndex + 1] = g;
        rgbBuffer[rgbIndex + 2] = b;
      }
    }

    return rgbBuffer;
  }

  Image.Image rgbToImage(Uint8List rgbBuffer, int width, int height) {
    final img = Image.Image(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final rgbIndex = (y * width + x) * 3;
        final r = rgbBuffer[rgbIndex];
        final g = rgbBuffer[rgbIndex + 1];
        final b = rgbBuffer[rgbIndex + 2];

        final color = Image.getColor(r, g, b);
        // final color = Image.ColorUint8.rgb(r.toInt(), g.toInt(), b.toInt());
        img.setPixel(x, y, color);
      }
    }

    return img;
  }

  List<double> softmax(List<double> x) {
    // Find the maximum value in the list (for numerical stability)
    final max = x.reduce((a, b) => a > b ? a : b);

    // Compute the exponentials and their sum
    final expValues = x.map((value) => exp(value - max)).toList();
    final sumExpValues = expValues.reduce((a, b) => a + b);

    // Compute the softmax by dividing each exponential value by the sum of exponentials
    return expValues.map((value) => value / sumExpValues).toList();
  }
}
