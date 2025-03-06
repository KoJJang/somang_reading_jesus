# Flutter Specific ProGuard Rules

# Keep Flutter wrapper code
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Firebase Auth
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Firebase Firestore
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# PlayCore
-keep class com.google.android.play.core.** { *; }

# SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Ignore warnings about missing classes from the Android SDK
-dontwarn android.support.**
-dontwarn androidx.**
-dontwarn com.google.android.play.core.**

# Keep model classes
-keep class com.somangchurch.readingjesus.data.models.** { *; } 