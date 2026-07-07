# Keep JNI-referenced Android plugin types stable in release builds.
-keep class com.submersion.libdivecomputer.LibdcWrapper { *; }
-keep class com.submersion.libdivecomputer.DescriptorInfo {
    <fields>;
    <init>();
}
-keep interface com.submersion.libdivecomputer.BleIoHandler { *; }
-keep interface com.submersion.libdivecomputer.DownloadCallback { *; }

# libdc_jni.cpp resolves the I/O handler passed to nativeDownloadRun by METHOD
# NAME: GetMethodID(GetObjectClass(handler), "read"/"write"/"purge"/"close"/
# "configure"/"setDtr"/"setRts", ...). R8 cannot see those native call sites,
# so without these rules it DELETES the methods outright (no visible caller)
# and every release-build serial download dies natively right after
# "nativeDownloadRun begin" -- the failed GetMethodID leaves a pending
# NoSuchMethodError and the next JNI call is undefined behavior (issue #318,
# fourth root cause; found via R8's usage.txt listing the stripped methods).
# Keeping the interfaces pins the method names on every implementation, the
# same mechanism that already protected BleIoHandler implementers above; the
# implements-wildcard is belt and braces for the concrete classes
# (UsbSerialIoStream, BleIoStream, and any future handler) and also pins
# their class names. Strictly only the METHOD names need to survive (JNI
# resolves the class via GetObjectClass, never FindClass, so a renamed class
# would be harmless) -- the CI guard in scripts/check_proguard_serial_keep.py
# enforces exactly that minimal contract against the release mapping.txt,
# while these rules are deliberately broader for safety. DO NOT REMOVE.
-keep interface com.submersion.libdivecomputer.IoHandler { *; }
-keep interface com.submersion.libdivecomputer.SerialIoHandler { *; }
-keep class * implements com.submersion.libdivecomputer.IoHandler { *; }

# Keep the vendored usb-serial-for-android drivers (serial-over-USB dive
# computer support, e.g. the Mares Puck Pro). These classes are discovered
# purely by reflection, so R8 has no visible call site and would rename or
# strip the members, breaking the lookups at runtime:
#   - ProbeTable.addDriver() -> Class.getMethod("getSupportedDevices") / ("probe")
#   - UsbSerialProber.probeDevice() -> Class.getConstructor(UsbDevice.class)
# When the members are renamed the reflective lookup throws NoSuchMethodException,
# which surfaces as "Download failed unexpectedly (RuntimeException)" and every
# serial-USB download crashes (issue #318). This mirrors the consumer ProGuard
# rules that the upstream library ships in its AAR; we vendor the source, so the
# rules must live here. DO NOT REMOVE.
-keep class com.hoho.android.usbserial.driver.** { *; }
