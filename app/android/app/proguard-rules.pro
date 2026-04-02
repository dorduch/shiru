# Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Dart entry points
-keep class **.GeneratedPluginRegistrant { *; }

# Keep annotations used by Flutter plugins
-keepattributes *Annotation*

# Suppress notes about missing classes referenced by reflection
-dontnote io.flutter.**

# Play Store deferred components (referenced by Flutter engine but not used)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# SQLCipher / SQLite encryption
-keep class net.zetetic.** { *; }
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Tink crypto (used by flutter_secure_storage)
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# OkHttp / networking stack (used by Dart http client)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class javax.net.ssl.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Conscrypt (SSL/TLS provider)
-keep class org.conscrypt.** { *; }
-dontwarn org.conscrypt.**

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
