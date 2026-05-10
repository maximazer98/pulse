# Flutter keeps its own rules; this file adds app-level rules.
# Keep Flutter plugin classes (required for flame_audio / vibration plugins).
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep audioplayers and vibration plugin entry points.
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.github.kazemihabib.flutter_vibration.** { *; }

# Suppress notes about missing references in third-party libs.
-dontnote kotlinx.serialization.**
-dontnote com.sun.**

# Play Core split-install classes referenced by Flutter but not used in this app.
-dontwarn com.google.android.play.core.**
