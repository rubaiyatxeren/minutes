# Facebook / Fresco WebP transcoder classes referenced by Jitsi/React Native
-dontwarn com.facebook.imagepipeline.nativecode.**
-keep class com.facebook.imagepipeline.nativecode.** { *; }

# Prevent R8 from stripping Jitsi / React Native native bindings
-keep class com.facebook.react.** { *; }
-keep class com.facebook.hermes.** { *; }
-dontwarn com.facebook.react.**
-dontwarn com.facebook.hermes.**

# WebRTC and Jitsi SDK Keep Rules
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class org.jitsi.meet.sdk.** { *; }
-dontwarn org.jitsi.meet.sdk.**

# Keep generic JNI Native interfaces
-keepclasseswithmembernames class * {
    native <methods>;
}