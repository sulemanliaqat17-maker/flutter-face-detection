import 'package:camera/camera.dart';
import 'package:face_detection_app/FaceDetection7.dart';
import 'package:face_detection_app/FaceEmbedding.dart';
import 'package:face_detection_app/widgets/customizable_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

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
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: false,
      splitScreenMode: false,
      builder: (BuildContext context, Widget? child) {
        return child!;
      },
      child: MaterialApp(
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
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final nameController = TextEditingController();
  final nameFocusNode = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomizableTextField(
              title: null,
              controller: nameController,
              textfieldDecorationType: TextfieldDecorationType.Outline,
              hintText: "Enter Your Name",
              focusNode: nameFocusNode,
              validator: (value) {
                if (value!.length < 3) {
                  return "Enter Correct Name";
                } else {
                  return null;
                }
              },
              onChanged: (value) {},
              prefixIcon: null,
              suffixIcon: null,
              prefixWidget:
                  SvgPicture.asset("assets/svgs/ic_fullname.svg", height: 16.h, width: 22.w),
              //Prefix Widget != null
              prefixPadding: EdgeInsets.only(left: 26.w, right: 10.w, top: 16.h, bottom: 16.h),
              suffixPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
              focusedIconColor: Colors.black,
              unfocusedIconColor: Colors.grey,
              hideText: false,
              textInputType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(
              height: 20.h,
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final cameras = await availableCameras();
                  await FaceEmbedding1.instance.loadModel();
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CameraScreen7(
                                cameras: cameras,
                                name: nameController.text,
                              )));
                  await FaceEmbedding1.instance.dispose();
                }
              },
              child: Text("FaceDetect"),
            ),
          ],
        ),
      ),
    ));
  }
}
