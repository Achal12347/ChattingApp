# Keep Flutter embedding and generated plugin registration.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep Firebase messaging classes used by notifications.
-keep class com.google.firebase.messaging.** { *; }
