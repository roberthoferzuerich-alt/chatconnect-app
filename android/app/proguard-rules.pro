# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.**

# Zego Cloud rules
-keep class im.zego.** { *; }
-dontwarn im.zego.**
-keep class com.zegocloud.** { *; }
-dontwarn com.zegocloud.**

# Firebase rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Sqflite rules
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**
