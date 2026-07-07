# Silence SnakeYAML's bean introspection errors
-dontwarn java.beans.**
-dontwarn org.yaml.snakeyaml.**

# Prevent R8 from stripping anything used via reflection
-keep class java.beans.** { *; }
-keep class org.yaml.snakeyaml.** { *; }

# google_mlkit_text_recognition references optional language recognizers
# that are not bundled; suppress R8 missing-class errors for them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
