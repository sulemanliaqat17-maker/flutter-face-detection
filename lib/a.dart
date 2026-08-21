import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:face_detection_app/FaceEmbedding.dart';
import 'package:face_detection_app/models/FaceData.dart';
import 'package:face_detection_app/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as Image;
import 'package:opencv_dart/opencv.dart' as cv;
import 'package:timer_count_down/timer_controller.dart';
import 'package:timer_count_down/timer_count_down.dart';

import '../../providers/api_face_detector_notifier.dart';

class CameraScreen7a extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  final String name;

  CameraScreen7a({required this.cameras, required this.name});

  @override
  _CameraScreen7aState createState() => _CameraScreen7aState();
}

class _CameraScreen7aState extends ConsumerState<CameraScreen7a> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool isProcessing = false;
  int fake = 0;
  int real = 0;
  int iteration = 0;
  bool isStartedStreaming = false;
  final CountdownController _countdownController =
      CountdownController(autoStart: true);
  bool countdownHide = true;
  Size? size;
  double aspectRatio = 0.0;
  List<Face>? faces = [];
  List<double>? faceEmbedding = [];
  List<dynamic>? outputModel1 = [];
  List<dynamic>? resultModel1 = [];
  List<dynamic>? outputModel2 = [];
  List<dynamic>? resultModel2 = [];
  List<double>? prediction = [];
  Image.Image? croppedImage;
  InputImage? inputImage;
  Face? face;
  Uint8List? image = null;
  Uint8List? image1 = null;

  // Distance guidance state
  String distanceMessage = "";
  Color distanceColor = Colors.red;

  // Face-size (distance) thresholds as a fraction of the full frame area.
  // Tune these using the debug print in _processImage.
  static const double _minFaceAreaRatio = 0.10; // below => face too far
  static const double _maxFaceAreaRatio = 0.15; // above => face too close
  double spoofConfidence = 0.0;
  int _selectedCameraIndex = 0; // set to the front camera in initState
  bool _isSwitchingCamera = false;

  // Only the bounding box is used downstream, so contours/classification are
  // left off and fast mode is used to keep every camera frame's detection
  // pass cheap.
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
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
    // Default to the front camera (preserves the original cameras[1] behaviour).
    _selectedCameraIndex = widget.cameras
        .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;
    _initializeCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() {
        countdownHide = false;
      });
      _countdownController.start();
    });
    // _loadORCModel();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _initializeControllerFuture = _controller!.initialize();
    await _initializeControllerFuture;
    aspectRatio = _controller!.value.aspectRatio;
    double? zoomLevelMax = await _controller?.getMaxZoomLevel();
    double? zoomLevelMin = await _controller?.getMinZoomLevel();
    print(zoomLevelMin);
    if (zoomLevelMax != null) {
      await _controller?.setZoomLevel(zoomLevelMin!);
    }
    // Start image stream
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    // _faceDetector.close();
    _controller = null;
    isProcessing = false;
    fake = 0;
    real = 0;
    iteration = 0;
    isStartedStreaming = false;
    countdownHide = true;
    size = null;
    aspectRatio = 0.0;
    faces = [];
    faceEmbedding = [];
    outputModel1 = [];
    resultModel1 = [];
    outputModel2 = [];
    resultModel2 = [];
    prediction = [];
    croppedImage = null;
    inputImage = null;
    face = null;
    distanceMessage = "";
    _isSwitchingCamera = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // isProcessing = ref.watch(isProcessingProvider);
    // iteration = ref.watch(iterationProvider);
    image = ref.watch(imageMemoryProvider);
    image1 = ref.watch(imageMemory1Provider);
    size = MediaQuery.of(context).size;
    spoofConfidence = ref.watch(spoofConfidenceProvider);
    return PopScope(
      canPop: true,
      onPopInvoked: (value) async {
        await _faceDetector.close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Face Embedding with Camera'),
        ),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (_isSwitchingCamera ||
                _controller == null ||
                !(_controller?.value.isInitialized ?? false)) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.connectionState == ConnectionState.done) {
              return Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                child: Column(
                  children: [
                    // Container(
                    //   color: Colors.white,
                    //   padding:
                    //       EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    //   child: Row(
                    //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //     children: [
                    //       Text("Fake: ${ref.watch(fakeCountProvider)}"),
                    //       Text("Real: ${ref.watch(realCountProvider)}"),
                    //     ],
                    //   ),
                    // ),
                    SizedBox(
                      height: 100.h,
                    ),
                    Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            /*Container(
                              width: 250.w,
                              height: 250.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.purple, width: 5.w),
                              ),
                              child: ClipOval(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: aspectRatio >= 1
                                        ? 190.w * aspectRatio
                                        : 190.w,
                                    height: aspectRatio >= 1
                                        ? 340.h
                                        : 340.h / aspectRatio,
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
                                                (time.toInt() == 0)
                                                    ? "Capturing..."
                                                    : time.toInt().toString(),
                                                style: TextStyle(
                                                  fontSize: 40,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              interval:
                                                  Duration(milliseconds: 100),
                                              onFinished: () async {
                                                // Retake or capture logic
                                                setState(() {
                                                  countdownHide = true;
                                                  isProcessing = false;
                                                });
                                                await _controller
                                                    ?.startImageStream(
                                                        startImageProcess);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),*/
                            Container(
                              width: 250.w,
                              height: 250
                                  .w, // same unit on both axes => a real circle on every device
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.purple, width: 5.w),
                              ),
                              child: ClipOval(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    // Match the CameraPreview's true portrait aspect ratio so it fills
                                    // this box with no letterboxing. FittedBox(cover) then scales it to
                                    // fill the circle identically on all devices.
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
                                                (time.toInt() == 0)
                                                    ? "Capturing..."
                                                    : time.toInt().toString(),
                                                style: TextStyle(
                                                  fontSize: 40,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              interval:
                                                  Duration(milliseconds: 100),
                                              onFinished: () async {
                                                setState(() {
                                                  countdownHide = true;
                                                  isProcessing = false;
                                                });
                                                await _controller
                                                    ?.startImageStream(
                                                        startImageProcess);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            ElevatedButton.icon(
                              onPressed:
                                  _isSwitchingCamera ? null : _switchCamera,
                              icon: Icon(Icons.cameraswitch),
                              label: Text("Switch Camera"),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              distanceMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: distanceColor,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "Live Attempts: $real",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "Fake Attempts: $fake",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "Spoof Confidence: $spoofConfidence",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(
                              height: 30.h,
                            ),
                            // image != null
                            //     ? Container(
                            //         height: 148.h,
                            //         width: 148.w,
                            //         decoration: BoxDecoration(
                            //           image: DecorationImage(
                            //             image: MemoryImage(image!),
                            //             fit: BoxFit.contain,
                            //           ),
                            //         ),
                            //       )
                            //     : FlutterLogo(
                            //         size: 100.sp,
                            //       ),
                            // image1 != null
                            //     ? Container(
                            //         height: 148.h,
                            //         width: 148.w,
                            //         decoration: BoxDecoration(
                            //           image: DecorationImage(
                            //             image: MemoryImage(image1!),
                            //             fit: BoxFit.contain,
                            //           ),
                            //         ),
                            //       )
                            //     : FlutterLogo(
                            //         size: 100.sp,
                            //       ),
                            // CameraPreview(_controller),
                            // LoadImageWidget(),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Future<void> startImageProcess(CameraImage image) async {
    if (FaceEmbedding1.instance.interpreter.isAllocated) {
      if (!isProcessing) {
        setState(() {
          isProcessing = true;
        });
        // await _processImage(image, widget.cameras[1]);
        await _processImage(image, widget.cameras[_selectedCameraIndex]);
      }
    } else {
      print("Not Allocated");
    }
  }

  Future<void> _switchCamera() async {
    // Need at least two cameras and no switch already in progress.
    if (widget.cameras.length < 2 || _isSwitchingCamera) return;

    // Work out the next camera: toggle between front and back.
    final currentLens = widget.cameras[_selectedCameraIndex].lensDirection;
    int nextIndex =
        widget.cameras.indexWhere((c) => c.lensDirection != currentLens);
    if (nextIndex == -1) {
      // Fallback: cycle to the next camera in the list.
      nextIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    }

    // 1. Stop prediction: stop the running image stream.
    try {
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    } catch (_) {}

    // Show the spinner while tearing down/rebuilding, so we never paint a
    // preview on a disposed controller.
    setState(() {
      _isSwitchingCamera = true;
      countdownHide = true;
      isProcessing = false;
    });

    // 2. Reset all prediction state so the new camera starts from scratch.
    fake = 0;
    real = 0;
    iteration = 0;
    distanceMessage = "";
    distanceColor = Colors.red;
    ref.refresh(fakeCountProvider);
    ref.refresh(realCountProvider);
    ref.refresh(spoofConfidenceProvider);

    // 3. Dispose the old controller and switch to the new camera.
    await _controller?.dispose();
    _controller = null;
    _selectedCameraIndex = nextIndex;

    // 4. Re-initialize the new camera (reassigns _initializeControllerFuture).
    await _initializeCamera();
    if (!mounted) return;

    // 5. Reveal the preview again.
    setState(() {
      _isSwitchingCamera = false;
    });

    // 6. Restart the 4-3-2-1 countdown (same pattern as initState). When it
    //    finishes, onFinished starts the image stream on the new camera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        countdownHide = false;
      });
      _countdownController.start();
    });
  }

  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    if (_controller == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
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

  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    return InputImage.fromBytes(
      bytes: allBytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        rotation:
            InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
                InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _processImage(
      CameraImage? image, CameraDescription camera) async {
    if (image != null) {
      // inputImage = _convertCameraImage(image, camera);
      inputImage = _inputImageFromCameraImage(image, camera);
      // ref.read(imageMemoryProvider.notifier).state = Image.encodePng(inputImage.bytes) as Uint8List;
      try {
        if (inputImage != null) {
          faces = await _faceDetector.processImage(inputImage!);
          if (faces!.isNotEmpty) {
            face = faces!.reduce((curr, next) =>
                curr.boundingBox.width * curr.boundingBox.height >
                        next.boundingBox.width * next.boundingBox.height
                    ? curr
                    : next);

            // --- Face distance check ------------------------------------
            // Bounding-box area vs full-frame area. Area is invariant to
            // the 90/270 rotation ML Kit applies, so this stays correct
            // in portrait.
            final double faceArea =
                face!.boundingBox.width * face!.boundingBox.height;
            final double frameArea = (image.width * image.height).toDouble();
            final double faceAreaRatio = faceArea / frameArea;
            if (kDebugMode) print("Face area ratio: $faceAreaRatio");

            if (faceAreaRatio < _minFaceAreaRatio) {
              inputImage = null;
              faces = null;
              face = null;
              if (mounted) {
                setState(() {
                  distanceMessage = "Move closer to the camera";
                  distanceColor = Colors.orange;
                  isProcessing = false;
                });
              }
              return;
            } else if (faceAreaRatio > _maxFaceAreaRatio) {
              inputImage = null;
              faces = null;
              face = null;
              if (mounted) {
                setState(() {
                  distanceMessage = "Move a little away from the camera";
                  distanceColor = Colors.orange;
                  isProcessing = false;
                });
              }
              return;
            } else if (distanceMessage != "Good distance, hold still") {
              if (mounted) {
                setState(() {
                  distanceMessage = "Good distance, hold still";
                  distanceColor = Colors.green;
                });
              }
            }
            // ------------------------------------------------------------

            fake = ref.read(fakeCountProvider);
            real = ref.read(realCountProvider);
            Map<String, dynamic>? data =
                await _extractFaceData(face!, image, ref, camera);
            bool? isFake = data["Fake"];
            // Image.Image croppedImage = data["CroppedImage"] as Image.Image;

            ref.read(fakeCountProvider.notifier).state =
                isFake! ? (fake + 1) : fake;
            ref.read(realCountProvider.notifier).state =
                isFake! ? real : (real + 1);

            if (ref.read(fakeCountProvider) == 10 ||
                ref.read(realCountProvider) == 10) {
              if (ref.read(fakeCountProvider.notifier).state > 10) {
                ref.refresh(fakeCountProvider);
                ref.refresh(realCountProvider);
                ref.refresh(spoofConfidenceProvider);
                // Fluttertoast.showToast(
                //     msg:
                //         "Kindly ensure that the facial registration of this person is bright and clear.");
                Fluttertoast.showToast(msg: "Multiple Fake Attempts Occurred");
              } else {
                faceEmbedding = await FaceEmbedding1.instance
                    .getFaceEmbedding(croppedImage!);
                if (kDebugMode) print("Face Embedding: $faceEmbedding");
                ref.refresh(fakeCountProvider);
                ref.refresh(realCountProvider);
                ref.refresh(spoofConfidenceProvider);
                // _faceEmbedding.disposeModels();
                FaceData? recognizedFace =
                    await _recognizeFace(faceEmbedding!, ref);
                // await Future.delayed(Duration(seconds: 1));
                if (recognizedFace != null) {
                  print('Recognized face: ${recognizedFace.name}');
                  Fluttertoast.showToast(msg: 'Welcome ${recognizedFace.name}');
                } else {
                  Fluttertoast.showToast(
                      msg:
                          "Face Not Registered, Please register your face first");
                }
                recognizedFace = null;
                isFake = null;
                data = null;
                inputImage = null;
                faces = null;
                face = null;
                faceEmbedding = null;
                croppedImage = null;
                outputModel1 = null;
                resultModel1 = null;
                outputModel2 = null;
                resultModel2 = null;
                prediction = null;
              }
              Navigator.pop(context);
            } else {
              isFake = null;
              data = null;
              inputImage = null;
              faces = null;
              face = null;
              faceEmbedding = null;
              croppedImage = null;
              outputModel1 = null;
              resultModel1 = null;
              outputModel2 = null;
              resultModel2 = null;
              prediction = null;
              setState(() {
                isProcessing = false;
                iteration = iteration + 1;
              });
            }
          } else {
            inputImage = null;
            faces = null;
            face = null;
            faceEmbedding = null;
            croppedImage = null;
            outputModel1 = null;
            resultModel1 = null;
            outputModel2 = null;
            resultModel2 = null;
            prediction = null;
            setState(() {
              isProcessing = false;
            });
          }
        } else {
          print("null inputimage");
        }
      } catch (ex, stack) {
        debugPrintStack(stackTrace: stack, label: ex.toString());
        if (mounted) {
          setState(() {
            isProcessing = false;
          });
        }
      }
    }
  }

  Future<FaceData?> _recognizeFace(List<double> faceData, WidgetRef ref) async {
    double threshold = 0.8;
    List<FaceData> allFaces =
        await ref.read(databaseProvider).faceEmbeddingsDao.getAllFaces();
    if (allFaces.length != 0) {
      for (FaceData storedFace in allFaces) {
        double similarity = cosineSimilarity(
            faceData, Utils.parseEmbedding(storedFace.embedding!));
        print("Similarity: ${similarity}");
        if (similarity > threshold) {
          return storedFace;
        }
      }
    } else {
      return null;
    }
  }

  static double cosineSimilarity(
      List<double> embedding1, List<double> embedding2) {
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

  Future<Map<String, dynamic>> _extractFaceData(Face face, CameraImage image,
      WidgetRef ref, CameraDescription camera) async {
    // Step 1: Crop the face from the input image
    try {
      croppedImage = await cropFace1(
          Crop1DataInput(face: face, cameraImage: image, camera: camera));

      // Build the Mat directly from the already-decoded pixels instead of
      // encoding to PNG, writing to disk, and reading it back with imread.
      cv.Mat? mat = imageToMat(croppedImage!);
      cv.Mat? imageMat1 = await cropM(CropMDataInput(
          orgImg: mat,
          bbox: [
            face.boundingBox.left.toInt(),
            face.boundingBox.top.toInt(),
            face.boundingBox.width.toInt(),
            face.boundingBox.height.toInt(),
          ],
          scale: 2.7,
          outW: 80,
          outH: 80));
      final (success, imageBytes) = await cv.imencodeAsync(".jpg", imageMat1);
      print("Success: $success");
      if (success) {
        ref.read(imageMemoryProvider.notifier).state = imageBytes;
      }
      cv.Mat? imageMat2 = await cropM(CropMDataInput(
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
      final (success1, imageBytes1) = await cv.imencodeAsync(".jpg", imageMat2);
      print("Success: $success1");
      if (success1) {
        ref.read(imageMemory1Provider.notifier).state = imageBytes1;
      }
      mat.release();
      mat.dispose();

      outputModel1 = await FaceEmbedding1.instance
          .getDataFromModel1(/*bitmapImage1,*/ imageMat1);
      imageMat1.release();
      imageMat1.dispose();
      resultModel1 = await compute(softmax, (outputModel1 as List<double>));
      print("Model1 Output: $resultModel1");

      outputModel2 = await FaceEmbedding1.instance
          .getDataFromModel2(/*bitmapImage1,*/ imageMat2);
      imageMat2.release();
      imageMat2.dispose();
      resultModel2 = await compute(softmax, (outputModel2 as List<double>));
      print("Model2 Output: $resultModel2");
      mat = null;
      imageMat1 = null;
      imageMat2 = null;

      prediction = List<double>.filled(3, 0.0);
      for (int i = 0; i < prediction!.length; i++) {
        prediction![i] += resultModel1![i];
        prediction![i] += resultModel2![i];
      }

      print("Prediction: $prediction");

      var label =
          prediction!.indexOf(prediction!.reduce((a, b) => a > b ? a : b));

      bool isReal = (label == 1);
      double score = prediction![label] / 2;
      if (isReal) {
        ref.read(spoofConfidenceProvider.notifier).state = score;
      }

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
    } catch (ex, stack) {
      debugPrintStack(label: ex.toString(), stackTrace: stack);
      throw "Error: ${ex.toString()}";
    }
  }

  /// Wraps an in-memory [Image.Image] as a BGR [cv.Mat] via a bulk buffer
  /// copy, avoiding a PNG encode + disk write/read round trip per frame.
  cv.Mat imageToMat(Image.Image image) {
    final bytes = image.getBytes(format: Image.Format.bgr);
    return cv.Mat.fromList(
        image.height, image.width, cv.MatType.CV_8UC3, bytes);
  }

  Future<cv.Mat> fixOrientationIfNeeded(cv.Mat inputMat) async {
    // You can enhance this using EXIF data if from camera
    // Here we simply try rotating 90/180/270 if needed
    // This example assumes 90° clockwise rotation needed
    cv.Mat rotatedMat = cv.Mat.empty();
    await cv.rotateAsync(inputMat, cv.ROTATE_90_CLOCKWISE, dst: rotatedMat);
    return rotatedMat;
  }

  Future<cv.Mat> cropM(CropMDataInput data) async {
    /*int? srcH = data.orgImg.rows;
    int? srcW = data.orgImg.cols;

    List<int>? newBox = await compute(
        getNewBox, GetNewBoxDataInput(srcW: srcW, srcH: srcH, bbox: data.bbox, scale: data.scale));

    // Crop image
    int? cropWidth = newBox![2] - newBox![0];
    int? cropHeight = newBox![3] - newBox![1];

    cv.Mat croppedImg = await computeCropM(ComputeCropMDataInput(
        orgImg: data.orgImg, newBox: newBox!, cropWidth: cropWidth, cropHeight: cropHeight));

    // Resize to target dimensions
    cv.Mat dstImg = cv.Mat.empty();
    await cv.resizeAsync(
      croppedImg,
      (data.outW, data.outH),
      dst: dstImg,
    );*/

    // STEP 1: Scale the image by 2.7x
    cv.Mat scaledMat = cv.Mat.empty();
    await cv.resizeAsync(
      data.orgImg,
      (
        (data.orgImg.cols * data.scale).toInt(),
        (data.orgImg.rows * data.scale).toInt(),
      ),
      dst: scaledMat,
    );

    // STEP 2: Resize to 80x80
    cv.Mat resizedMat = cv.Mat.empty();
    await cv.resizeAsync(
      scaledMat,
      (data.outH, data.outW),
      dst: resizedMat,
    );

    // Clean up intermediate mat
    scaledMat.release();
    scaledMat.dispose();
    // mat.release();
    // mat.dispose();

    // Manual cleanup (recommended for memory management)
    // croppedImg.release(); // Uncomment if needed
    // croppedImg.release();
    // croppedImg.dispose();
    // aligned.release();
    // srcH = null;
    // srcW = null;
    // faceCrop.release();
    // faceCrop.dispose();
    // newBox = null;
    // cropWidth = null;
    // cropHeight = null;
    return resizedMat;
  }

  Future<cv.Mat> computeCropM(ComputeCropMDataInput data) async {
    cv.Mat? croppedImg =
        cv.Mat.zeros(data.cropHeight, data.cropWidth, data.orgImg.type);
    cv.Vec3b? pixel;
    int? srcX;
    int? srcY;
    int? y = 0;
    int? x = 0;
    for (y = 0; y! < data.cropHeight; y++) {
      for (x = 0; x! < data.cropWidth; x++) {
        srcX = x + data.newBox[0];
        srcY = y + data.newBox[1];
        pixel = data.orgImg.at<cv.Vec3b>(srcY, srcX);
        croppedImg.set(x, y, pixel);
        // croppedImg.at<cv.Vec3b>(y, x)/* = pixel*/;
      }
    }
    pixel = null;
    srcX = null;
    srcY = null;
    y = null;
    x = null;
    return croppedImg;
  }

  Future<Image.Image> cropFace1(Crop1DataInput data) async {
    // Get image dimensions
    int width = data.cameraImage.width;
    int height = data.cameraImage.height;

    Image.Image img = Image.Image(width, height);
    if (data.cameraImage.format.group == ImageFormatGroup.yuv420) {
      // Convert YUV to RGB
      img = _convertYuv420ToRgb(data.cameraImage);
    } else if (data.cameraImage.format.group == ImageFormatGroup.nv21) {
      DeviceOrientation? orientation =
          WidgetsBinding.instance.window.physicalSize.aspectRatio > 1
              ? DeviceOrientation.landscapeLeft
              : DeviceOrientation.portraitUp;
      img = await convertSinglePlaneNv21ToRgb(
          data.cameraImage, data.camera, orientation);
      orientation = null;
    } else if (data.cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // Convert BGRA to Image
      img = Image.Image.fromBytes(
        width,
        height,
        data.cameraImage.planes[0].bytes,
        format: Image.Format.bgra,
      );
    } else {
      throw Exception(
          'Unsupported image format: ${data.cameraImage.format.group}');
    }

    // Get face bounding box
    /*final rect = data.face.boundingBox;
    final left = rect.left.toInt();
    final top = rect.top.toInt();
    final right = rect.right.toInt();
    final bottom = rect.bottom.toInt();

    // Calculate width and height of the bounding box
    int fWidth = right - left;
    int fHeight = bottom - top;

    // Debug the bounding box values
    print('Bounding box: left=$left, top=$top, width=$fWidth, height=$fHeight');
    // Crop the face
    return Image.copyCrop(img, left, top, fWidth, fHeight);*/

    // Face bounding box
    final rect = data.face.boundingBox;

    int left = rect.left.toInt();
    int top = rect.top.toInt();
    int right = rect.right.toInt();
    int bottom = rect.bottom.toInt();

    int faceWidth = right - left;
    int faceHeight = bottom - top;

    // Padding percentage
    const double horizontalPadding = 0.20; // 20% each side
    const double verticalPadding = 0.30; // 30% top & bottom

    // Calculate padding
    final int paddingX = (faceWidth * horizontalPadding).toInt();
    final int paddingY = (faceHeight * verticalPadding).toInt();

    // Apply padding
    left -= paddingX;
    right += paddingX;

    top -= paddingY;
    bottom += paddingY;

    // Clamp crop coordinates to image boundaries
    left = left.clamp(0, width);
    top = top.clamp(0, height);
    right = right.clamp(0, width);
    bottom = bottom.clamp(0, height);

    // Calculate final crop dimensions
    final int cropWidth = right - left;
    final int cropHeight = bottom - top;

    print(
      'Face: left=$left, top=$top, '
      'width=$cropWidth, height=$cropHeight',
    );

    // Crop the face with padding
    return Image.copyCrop(
      img,
      left,
      top,
      cropWidth,
      cropHeight,
    );
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

  Future<Image.Image> convertSinglePlaneNv21ToRgb(
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
    Image.Image rgbImage = Image.Image(width, height);

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
}

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

Image.Image convertSinglePlaneNv21ToRgbCompute(
    ConvertNv21ToRgbaDataInput data) {
// The UV data starts after the Y data
  final uvData = data.yData.sublist(data.width * data.height);
  int y = 0;
  int x = 0;
  int yValue;
  int uvIndex;
  int vValue;
  int uValue;
  double r;
  double g;
  double b;
  for (y = 0; y < data.height; y++) {
    for (x = 0; x < data.width; x++) {
// Get Y value
      yValue = data.yData[y * data.width + x];

// Get U and V values (interleaved in NV21)
      uvIndex = (y ~/ 2) * (data.width ~/ 2) + (x ~/ 2);
      vValue = uvData[uvIndex * 2];
      uValue = uvData[uvIndex * 2 + 1];

// Convert YUV to RGB
      r = yValue + 1.402 * (vValue - 128);
      g = yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
      b = yValue + 1.772 * (uValue - 128);

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
  int? x = data.bbox[0];
  int? y = data.bbox[1];
  int? boxW = data.bbox[2];
  int? boxH = data.bbox[3];

  // Ensure the scale does not exceed the maximum allowed scale
  double? newScale = data.scale.clamp(0.0, (data.srcH - 1) / boxH);
  newScale = newScale.clamp(0.0, (data.srcW - 1) / boxW);

  // Calculate the new width and height
  double? newWidth = boxW * newScale;
  double? newHeight = boxH * newScale;

  // Calculate the center of the bounding box
  double? centerX = boxW / 2.0 + x;
  double? centerY = boxH / 2.0 + y;

  // Calculate the new bounding box coordinates
  double? leftTopX = centerX - newWidth / 2;
  double? leftTopY = centerY - newHeight / 2;
  double? rightBottomX = centerX + newWidth / 2;
  double? rightBottomY = centerY + newHeight / 2;

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
