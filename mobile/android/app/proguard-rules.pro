# Preserve debug line numbers and reflection/annotation metadata under R8
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions

# Flutter engine & embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <methods>;
}

# just_audio, audio_session & AndroidX Media3 (ExoPlayer)
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# flutter_secure_storage & Google Tink crypto
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# app_links (used by supabase_flutter OAuth/password reset deep linking)
-keep class com.llfbandit.app_links.** { *; }

# shared_preferences_android
-keep class io.flutter.plugins.sharedpreferences.** { *; }
