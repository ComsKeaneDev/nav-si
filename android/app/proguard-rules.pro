# Silence SnakeYAML's bean introspection errors
-dontwarn java.beans.**
-dontwarn org.yaml.snakeyaml.**

# Prevent R8 from stripping anything used via reflection
-keep class java.beans.** { *; }
-keep class org.yaml.snakeyaml.** { *; }
