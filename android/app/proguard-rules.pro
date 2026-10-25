# Frame privacy accepts our application namespace. Preserve class names so
# release R8 renaming cannot turn an application frame into an unknown path.
# Method optimization/renaming remains enabled; retain the matching mapping.txt.
-keepnames class com.settrace.settrace.**
-keepattributes SourceFile,LineNumberTable
