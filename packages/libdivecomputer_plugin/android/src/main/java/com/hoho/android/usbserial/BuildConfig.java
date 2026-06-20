package com.hoho.android.usbserial;

/**
 * Vendoring shim for usb-serial-for-android.
 *
 * Upstream the library ships its own AGP-generated {@code BuildConfig} under the
 * {@code com.hoho.android.usbserial} namespace. Because the sources are vendored
 * into this plugin module (namespace {@code com.submersion.libdivecomputer}),
 * that generated class is not produced here. A couple of drivers
 * (Ch34xSerialDriver, ProlificSerialDriver) import {@code BuildConfig.DEBUG} to
 * gate a debug-only custom-baud-rate diagnostic, so this stand-in satisfies the
 * import without modifying the vendored sources (keeping them syncable with
 * upstream). DEBUG is false: the gated code path is a developer diagnostic only.
 */
public final class BuildConfig {
    public static final boolean DEBUG = false;

    private BuildConfig() {}
}
