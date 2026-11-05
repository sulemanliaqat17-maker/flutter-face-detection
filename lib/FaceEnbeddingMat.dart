import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as Image;
import 'package:opencv_dart/opencv.dart' as cv;
import 'package:synchronized/synchronized.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceEmbeddingMat {
  static final FaceEmbeddingMat _instance = FaceEmbeddingMat._internal();

  // Private constructor
  FaceEmbeddingMat._internal();

  // Public access point
  static FaceEmbeddingMat get instance => _instance;
  late Interpreter interpreter;
  late Interpreter interpreter1;
  late Interpreter interpreter2;
  late IsolateInterpreter isolateInterpreter;
  late IsolateInterpreter isolateInterpreter1;
  late IsolateInterpreter isolateInterpreter2;
  bool _isInitialized = false;
  final _lock = Lock();

  Future<void> loadModel() async {
    await _lock.synchronized(() async {
      if (_isInitialized) return;
      try {
        interpreter =
            await Interpreter.fromAsset('assets/models/face_net_512.tflite');
        interpreter1 =
            await Interpreter.fromAsset('assets/models/first_model.tflite');
        interpreter2 =
            await Interpreter.fromAsset('assets/models/second_model.tflite');
        isolateInterpreter =
            await IsolateInterpreter.create(address: interpreter.address);
        isolateInterpreter1 =
            await IsolateInterpreter.create(address: interpreter1.address);
        isolateInterpreter2 =
            await IsolateInterpreter.create(address: interpreter2.address);
        _isInitialized = true;
      } catch (e) {
        print('Failed to load model: $e');
      }
    });
  }

  bool get isReady => _isInitialized;

  /// Dispose resources
  Future<void> dispose() async {
    await _lock.synchronized(() {
      interpreter.close();
      interpreter1.close();
      interpreter2.close();
      _isInitialized = false;
    });
  }

  List<double> preprocessFrame(Image.Image image) {
    // Resize the image to 160x160 (FaceNet input size)
    image = Image.copyResize(image, width: 160, height: 160);

    // Convert image to RGB and normalize pixel values to [-1, 1]
    List<double> input = [];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int pixel = image.getPixel(x, y);
        double r = (Image.getRed(pixel) / 127.5) - 1.0;
        double g = (Image.getGreen(pixel) / 127.5) - 1.0;
        double b = (Image.getBlue(pixel) / 127.5) - 1.0;
        input.addAll([r, g, b]);
      }
    }

    // Add batch dimension
    return input;
  }

  Future<List<double>> getFaceEmbedding(cv.Mat faceMat) async {
    if (!_isInitialized) throw Exception("Models not loaded");
    // Preprocess the frame
    // Convert cv.Mat to the expected input format
    // First ensure the image is in BGR format (OpenCV's default)
    final bgrMat = cv.Mat.empty();
    if (faceMat.channels == 1) {
      await cv.cvtColorAsync(faceMat, dst: bgrMat, cv.COLOR_GRAY2BGR);
    } else if (faceMat.channels == 4) {
      await cv.cvtColorAsync(faceMat, dst: bgrMat, cv.COLOR_BGRA2BGR);
    } else {
      await faceMat.copyToAsync(bgrMat);
    }

    // Resize to model input size (160x160)
    final resizedMat = cv.Mat.empty();
    await cv.resizeAsync(bgrMat, dst: resizedMat, (160, 160));
    bgrMat.release();

    // Convert to float32 and normalize pixel values to [-1, 1]
    cv.Mat floatMat = cv.Mat.empty();
    floatMat = await resizedMat.convertToAsync(cv.MatType.CV_32FC3,
        alpha: 2.0 / 255.0, beta: -1.0);
    resizedMat.release();

    // Get raw data as List<double>
    final bytes = floatMat.data;
    final input = bytes.buffer.asFloat32List().toList();
    floatMat.release();

    // Prepare input tensor
    var inputTensor = input.reshape([1, 160, 160, 3]);

    // Prepare output tensor with the correct shape [1, 512]
    var outputTensor = List<double>.filled(512, 0).reshape([1, 512]);

    // Run inference
    await isolateInterpreter.run(inputTensor, outputTensor);

    // Return the face embedding
    return outputTensor[0];
  }

  Future<Float32List> preprocessImage(
      cv.Mat image, int targetWidth, int targetHeight) async {
    // Resize the image to target dimensions
    final resizedImage = cv.Mat.empty();
    await cv.resizeAsync(
      image,
      (targetWidth, targetHeight),
      dst: resizedImage,
      interpolation: cv.INTER_LINEAR,
    );

    // Convert BGR to RGB
    final rgbImage = cv.Mat.empty();
    await cv.cvtColorAsync(resizedImage, dst: rgbImage, cv.COLOR_BGR2RGB);
    resizedImage.release();

    // Read the whole RGB buffer in a single FFI call, then widen the
    // uint8 pixels (0-255, row-major, RGB) to float32 in one tight Dart
    // loop. This is identical in value to the old per-pixel atPixel()
    // path but avoids ~targetWidth*targetHeight FFI round trips per frame.
    final rgbBytes = rgbImage.data;
    rgbImage.release();

    final floatArray = Float32List(rgbBytes.length);
    for (var i = 0; i < rgbBytes.length; i++) {
      floatArray[i] = rgbBytes[i].toDouble();
    }

    return floatArray;
  }

  Future<List<dynamic>> getDataFromModel1(
      /*Uint8List image,*/ cv.Mat matImage) async {
    if (!_isInitialized) throw Exception("Models not loaded");
    // Preprocess the frame
    // final inputBuffer = Float32List(80 * 80 * 3); // 80x80 RGB image
    // for (int i = 0; i < image.length; i++) {
    //   inputBuffer[i] = image[i] / 1.0; // Normalize to [0, 1]
    // }
    final inputBuffer = await preprocessImage(matImage, 80, 80);
    matImage.release();
    // Prepare output tensor with the correct shape [1, 512]
    var outputTensor = List<double>.filled(3, 0).reshape([1, 3]);

    // Reshape to match the model's input shape [1, 80, 80, 3]

    // Prepare input tensor

    outputTensor = await computeModel1(
        Model1DataInput(inputBuffer: inputBuffer, outputTensor: outputTensor));

    // Return the face embedding
    return await outputTensor[0];
  }

  Future<List<dynamic>> computeModel1(Model1DataInput data) async {
    var inputTensor = data.inputBuffer.reshape([1, 80, 80, 3]);

    checkOutputShape(interpreter1);

    // Run inference
    await isolateInterpreter1.run(inputTensor, data.outputTensor);
    return data.outputTensor;
  }

  Future<List<dynamic>> getDataFromModel2(
      /*Uint8List image,*/ cv.Mat matImage) async {
    if (!_isInitialized) throw Exception("Models not loaded");
    // Preprocess the frame
    /*final inputBuffer = Float32List(80 * 80 * 3); // 80x80 RGB image
    for (int i = 0; i < image.length; i++) {
      inputBuffer[i] = image[i] / 255.0; // Normalize to [0, 1]
    }*/

    final inputBuffer = await preprocessImage(matImage, 80, 80);
    matImage.release();

    // Reshape to match the model's input shape [1, 80, 80, 3]

    // Prepare output tensor with the correct shape [1, 512]
    var outputTensor = List<double>.filled(3, 0).reshape([1, 3]);

    outputTensor = await computeModel2(
        Model1DataInput(inputBuffer: inputBuffer, outputTensor: outputTensor));

    // Return the face embedding
    return await outputTensor[0];
  }

  Future<List<dynamic>> computeModel2(Model1DataInput data) async {
    var inputTensor = data.inputBuffer.reshape([1, 80, 80, 3]);

    checkOutputShape(interpreter2);

    // Run inference
    await isolateInterpreter2.run(inputTensor, data.outputTensor);
    return data.outputTensor;
  }

  void checkOutputShape(Interpreter interpreter) {
    // Get output tensor details
    final outputTensors = interpreter.getOutputTensors();

    // Print output tensor details
    for (var tensor in outputTensors) {
      print('Output Tensor Name: ${tensor.name}');
      print('Output Tensor Shape: ${tensor.shape}');
      print('Output Tensor Type: ${tensor.type}');
    }
  }

  void disposeModels() {
    interpreter.close();
    interpreter1.close();
    interpreter2.close();
  }
}

class Model1DataInput {
  final Float32List inputBuffer;
  final List<dynamic> outputTensor;

  Model1DataInput({
    required this.inputBuffer,
    required this.outputTensor,
  });
}
