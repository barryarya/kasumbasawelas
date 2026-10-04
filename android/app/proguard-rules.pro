# ML Kit Text Recognition keep/dontwarn rules
# ML Kit includes optional support for Chinese, Devanagari, Japanese, and Korean.
# Since only Latin script is used, suppress warnings for the unreferenced language modules.
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.common.**
-dontwarn com.google_mlkit_text_recognition.**
-dontwarn com.google_mlkit_commons.**
-keep class com.google.mlkit.vision.text.** { *; }

