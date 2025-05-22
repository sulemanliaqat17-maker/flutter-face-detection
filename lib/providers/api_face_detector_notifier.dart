import 'dart:typed_data';

import 'package:face_detection_app/models/FaceData.dart';
import 'package:face_detection_app/models/states.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../database/my_database.dart';

final apiFaceDetectorNotifierProvider =
    StateNotifierProvider.autoDispose<ApiFaceDetectorNotifier, ApiStatesModel>(
        (ref) => ApiFaceDetectorNotifier(ref),
        name: "apiFaceDetectorNotifierProvider");

final databaseProvider = StateProvider((ref) => MyDatabase());
final imageMemoryProvider = StateProvider<Uint8List?>((ref) => null);
final imageProvider = StateProvider<InputImage?>((ref) => null);
final realCountProvider = StateProvider<int>((ref) => 0);
final fakeCountProvider = StateProvider<int>((ref) => 0);
final isProcessingProvider = StateProvider<bool>((ref) => false);
final iterationProvider = StateProvider<int>((ref) => 0);

class ApiFaceDetectorNotifier extends StateNotifier<ApiStatesModel> {
  final AutoDisposeStateNotifierProviderRef _ref;

  ApiFaceDetectorNotifier(this._ref) : super(ApiStatesModel(States.IDLE, "", null));

  /*void isLoading(String loadingMessage) {
    state = ApiStatesModel(States.LOADING, loadingMessage, null);
  }

  void isError(String errorMessage) {
    state = ApiStatesModel(States.ERROR, errorMessage, null);
  }

  void isSuccess(String successMessage) {
    state = ApiStatesModel(States.DATA, successMessage, null);
  }

  void isSessionExpired(String sessionExpiredMessage) {
    state = ApiStatesModel(States.SESSIONEXPIRED, sessionExpiredMessage, null);
  }*/

  // Future<void> apiSync() async {
  //   try {
  //     state = ApiStatesModel(States.LOADING, "", null);
  //     SyncResponse response = await _ref.read(authRepository).apiSync();
  //     if (response.success != null && response.success!) {
  //       await insertSyncResponse(response);
  //     }
  //     if (response.statusCode == 400) {
  //       state =
  //           ApiStatesModel(States.SESSIONEXPIRED, response.message!, response);
  //     } else if (response.statusCode == 1000) {
  //       state = ApiStatesModel(States.APPUPDATE, response, response);
  //     } else {
  //       state = ApiStatesModel(States.DATA, response.message!, response);
  //     }
  //   } on DataException catch (error) {
  //     state = ApiStatesModel(States.ERROR, error.message, null);
  //   }
  // }

  // Future<void> apiLogin(BuildContext context) async {
  //   String phoneNumber = _ref.watch(phoneLoginProvider);
  //   try {
  //     state = ApiStatesModel(States.LOADING, pleaseWaitSignIn, null);
  //     LoginResponse response =
  //         await _ref.read(authRepository).apiLogin(phoneNumber);
  //     state = ApiStatesModel(States.DATA, response.message!, response);
  //   } on DataException catch (error) {
  //     state = ApiStatesModel(States.ERROR, error.message, null);
  //   }
  // }

  Future<void> saveEmbeddings(String name, List<double> embedding) async {
    await _ref.read(databaseProvider).faceEmbeddingsDao.insertFace(name, embedding);
  }

  Future<List<FaceData>> getAllFaces() async {
    return await _ref.read(databaseProvider).faceEmbeddingsDao.getAllFaces();
  }
}

class ApiStatesModel {
  ApiStatesModel(this.states, this.message, this.data);

  States states;
  String message;
  dynamic data;
}
