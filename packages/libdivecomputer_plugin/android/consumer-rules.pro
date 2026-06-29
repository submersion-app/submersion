# Keep JNI-referenced Android plugin types stable in release builds.
-keep class com.submersion.libdivecomputer.LibdcWrapper { *; }
-keep class com.submersion.libdivecomputer.DescriptorInfo {
    <fields>;
    <init>();
}
-keep interface com.submersion.libdivecomputer.BleIoHandler { *; }
-keep interface com.submersion.libdivecomputer.DownloadCallback { *; }

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
