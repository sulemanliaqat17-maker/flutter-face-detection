
# Flutter Wrapper rules to prevent engine classes from being stripped
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ML Kit (face detection)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-dontwarn com.google.mlkit.**

# TensorFlow Lite (keep as a safety net; harmless if unused)
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**

# Keep data models intact if you rely on JSON serialization (Gson, Moshi, etc.)
# Replace with your actual Android package name if you have native models
# -keep class com.yourcompany.yourapp.models.** { *; }

# Suppress warnings that might halt your build
-dontwarn io.flutter.**

-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
