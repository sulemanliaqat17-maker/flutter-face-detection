import 'package:camera/camera.dart';
import 'package:face_detection_app/FaceDetection7.dart';
import 'package:face_detection_app/FaceEmbedding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'utils/logger.dart';

void main() {
  // runApp(const MyApp());
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(observers: [Logger()], child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeView(),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () async {
              final cameras = await availableCameras();
              await FaceEmbedding1.instance.loadModel();
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CameraScreen7(
                            cameras: cameras,
                            name: "Abdul Manan",
                          )));
              await FaceEmbedding1.instance.dispose();
            },
            child: Text("FaceDetect"),
          ),
        ],
      ),
    ));
  }
}
