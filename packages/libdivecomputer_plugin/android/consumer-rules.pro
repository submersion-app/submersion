# Keep JNI-referenced Android plugin types stable in release builds.
-keep class com.submersion.libdivecomputer.LibdcWrapper { *; }
-keep class com.submersion.libdivecomputer.DescriptorInfo {
    <fields>;
    <init>();
}
-keep interface com.submersion.libdivecomputer.BleIoHandler { *; }
-keep interface com.submersion.libdivecomputer.DownloadCallback { *; }
