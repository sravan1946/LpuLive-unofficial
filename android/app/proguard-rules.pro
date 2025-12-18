# Flutter Local Notifications - Gson TypeToken preservation
# This is required to prevent R8 from stripping generic type information
# that Gson needs for deserialization

# Keep Gson TypeToken classes and preserve generic signatures
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Preserve generic signatures for TypeToken
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep the FlutterLocalNotificationsPlugin classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep notification data classes
-keep class * implements java.io.Serializable { *; }
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep classes used by Gson for notification serialization
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

