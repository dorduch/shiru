# Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Dart entry points
-keep class **.GeneratedPluginRegistrant { *; }

# Keep annotations used by Flutter plugins
-keepattributes *Annotation*

# Suppress notes about missing classes referenced by reflection
-dontnote io.flutter.**
