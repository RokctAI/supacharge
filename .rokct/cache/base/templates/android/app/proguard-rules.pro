# Play's Feb 2027 DEX-optimization requirement needs R8 optimization on
# (build.gradle uses proguard-android-optimize.txt, which omits the
# -dontoptimize that proguard-android.txt sets). A bare `-keep` blocks
# shrinking, optimization AND obfuscation for the matched classes, so the
# broad keeps below were also silently opting their code out of
# optimization. The `allowoptimization` modifier keeps every matched class
# and member present under its original name -- which is the only thing
# these rules were ever protecting (plugin registration and name-based
# reflection) -- while letting R8 optimize the method bodies. Do not drop
# the modifier without re-checking the r8.json optimization percentage in
# BUNDLE-METADATA/com.android.tools/.

# Keep device_info plugin classes
-keep,allowoptimization class io.flutter.plugins.deviceinfo.** { *; }

# Keep plugin classes in general
-keep,allowoptimization class io.flutter.plugins.** { *; }
-keep,allowoptimization class io.flutter.plugin.**  { *; }

# Additional common rules for Flutter apps
-keep,allowoptimization class androidx.lifecycle.** { *; }
-keep,allowoptimization class androidx.core.** { *; }
-keep,allowoptimization class androidx.fragment.** { *; }

# Optional HMS/EMUI and BouncyCastle paths referenced by Huawei SDKs but not
# bundled; guarded at runtime, so suppress R8's missing-class errors.
-dontwarn com.huawei.android.os.**
-dontwarn com.huawei.hianalytics.**
-dontwarn com.huawei.libcore.io.**
-dontwarn org.bouncycastle.**

# Optional platform bridges, resolved by name in MainActivity's
# registerOptionalBridges. R8 sees no reference to them at all, so without a
# keep they are shrunk out of the release build and the lookup throws
# ClassNotFoundException - which the caller correctly reads as "this app was
# composed without that SDK" and silently does nothing, in release only.
# The class name must also survive obfuscation (no allowobfuscation), and
# `public *` covers both callable shapes: the INSTANCE singleton of a Kotlin
# `object` and a @JvmStatic register.
-keep,allowoptimization class **.DefaultHomeBridge { public *; }
-keep,allowoptimization class **.AppChangesBridge { public *; }
