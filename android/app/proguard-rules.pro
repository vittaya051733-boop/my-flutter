# Keep rules and warnings suppression for ML Kit Text Recognition optional language packs
# Based on generated missing_rules.txt during R8 shrink
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# General ML Kit packages (avoid failing when optional modules aren't present)
-dontwarn com.google.mlkit.**

# Keep plugin bridge classes used by Flutter ML Kit plugin
-keep class com.google_mlkit_text_recognition.** { *; }

# Flutter / Plugins generic safety
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# ONNX runtime used by image_background_remover on Android release builds
-keep class ai.onnxruntime.** { *; }
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase Phone Auth / reCAPTCHA Enterprise (release R8)
-keep class com.google.android.recaptcha.** { *; }
-dontwarn com.google.android.recaptcha.**
-keep class com.google.firebase.auth.** { *; }

# Printing plugin (uses reflection)
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn net.nfet.flutter.printing.**

# Agora RTC
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Mobile scanner / ML Kit
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Maps
-keep class com.google.android.libraries.maps.** { *; }
-dontwarn com.google.android.libraries.maps.**

# Keep Parcelables / Serializables
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepnames class * implements java.io.Serializable

# Keep annotations
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
