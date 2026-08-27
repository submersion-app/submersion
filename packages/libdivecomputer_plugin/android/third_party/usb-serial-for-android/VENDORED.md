# Vendored: usb-serial-for-android

The Java sources under `android/src/main/java/com/hoho/android/usbserial/`
(packages `driver/` and `util/`) are vendored, unmodified, from:

- **Project:** https://github.com/mik3y/usb-serial-for-android
- **Version:** v3.9.0 (commit `e1018ab`)
- **License:** MIT (see `LICENSE.txt` in this directory)

## Why vendored

Android cannot use libdivecomputer's POSIX serial backend (`serial_posix.c` is
excluded from the NDK build). USB-to-serial dive computers (e.g. the Mares Puck
Pro on an FTDI cable) must be driven through the Android USB Host API, with a
per-chip driver (FTDI, CP210x, CH34x, Prolific, CDC-ACM). This library provides
those drivers. It is vendored rather than pulled as a Gradle dependency to keep
the plugin build self-contained.

## How it is used

`UsbSerialIoStream.kt` adapts a `UsbSerialPort` to libdivecomputer's synchronous
I/O callbacks (read/write/configure/setDtr/setRts) via the JNI bridge. We call
`UsbSerialPort.read`/`write` synchronously and do NOT use the library's
`util/SerialInputOutputManager` async worker (libdivecomputer drives I/O on its
own download thread).

## Local additions (not from upstream)

- `com/hoho/android/usbserial/BuildConfig.java` — a small stand-in for the
  AGP-generated `BuildConfig` that upstream produces under its own namespace.
  Vendoring into this module does not regenerate it, and two drivers import
  `BuildConfig.DEBUG`. This shim satisfies that import without editing the
  vendored sources. Delete/regenerate if upstream packaging changes.

## Updating

Re-copy the `com/hoho/android/usbserial/{driver,util}` tree from the upstream tag
and update the version/commit above. Keep the upstream sources unmodified so
fixes can be re-applied cleanly (the `BuildConfig.java` shim above is the only
local addition). The only external dependency is `androidx.annotation`
(declared in `android/build.gradle`).
