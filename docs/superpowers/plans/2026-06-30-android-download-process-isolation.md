# Android Download Process Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the Android serial dive-computer download in a separate `:dc` process so a native `SIGSEGV` there is contained — the app reports "download failed" and stays alive.

**Architecture:** A bound `DiveDownloadService` (`android:process=":dc"`) runs the whole serial stack (USB + `usb-serial-for-android` + `nativeDownloadRun`). The main-process `SerialDownloadClient` binds it, forwards the request over AIDL, re-emits `onProgress`/`onDive`/`onError`/`onComplete` to Flutter through the **unchanged** Pigeon `flutterApi`, and detects a child crash via `IBinder.linkToDeath`. Dives cross as `byte[]` encoded with the plugin's own Pigeon codec.

**Tech Stack:** Kotlin 1.8.22, AGP 8.1.0, Android AIDL, `io.flutter.plugin.common.StandardMessageCodec` (Pigeon), `usb-serial-for-android` (vendored), libdivecomputer JNI.

## Global Constraints

- Package/namespace: `com.submersion.libdivecomputer`.
- Kotlin 1.8.22, AGP 8.1.0, `minSdk 21`, `compileSdk 34`, `jvmTarget 1.8`.
- **Serial-first:** only `TransportType.SERIAL` / `TransportType.USB` move to `:dc`. BLE download and device discovery stay in the main process, unchanged.
- **No in-process fallback:** if `:dc` can't bind or dies, report an error — never run the serial download in the main process.
- **Pigeon contract unchanged:** no edits to `DiveComputerApi.g.kt`, the `.dart` Pigeon defs, or the Dart layer. The Flutter-facing behavior of `startDownload`/`cancelDownload` and the `flutterApi.*` callbacks is identical.
- Dive marshaling reuses the existing codec via the public `DiveComputerHostApi.codec`; do not hand-duplicate the `ParsedDive` schema.
- `LIBDC_TRANSPORT_SERIAL = 1`, `LIBDC_STATUS_CANCELLED = -10` (already defined in `DiveComputerHostApiImpl.kt:16,22`).

---

## File structure

**Create**
- `packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/IDiveDownloadService.aidl`
- `packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/IDiveDownloadCallback.aidl`
- `packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/SerialDownloadRequest.aidl` (parcelable declaration)
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRequest.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveMarshaling.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveDownloadService.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadClient.kt`
- `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/DiveMarshalingTest.kt`
- `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/DownloadIsolationTest.kt`
- `scripts/check_dc_process_isolation.py`
- `scripts/check_dc_process_isolation_test.py`

**Modify**
- `packages/libdivecomputer_plugin/android/build.gradle` — enable AIDL, add androidTest deps.
- `packages/libdivecomputer_plugin/android/src/main/AndroidManifest.xml` — declare the `:dc` service.
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` — delegate the serial branch to `SerialDownloadClient`; route cancel; add the debug crash-hook plumbing.
- `.github/workflows/ci.yaml` — run the new guard + its self-test.

---

## Task 1: Declare the `:dc` service + CI manifest guard

Establishes the process boundary and a guard so it can't be silently removed. No runtime behavior yet.

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/build.gradle`
- Modify: `packages/libdivecomputer_plugin/android/src/main/AndroidManifest.xml`
- Create: `scripts/check_dc_process_isolation.py`
- Create: `scripts/check_dc_process_isolation_test.py`
- Modify: `.github/workflows/ci.yaml`

**Interfaces:**
- Produces: an AndroidManifest `<service android:name=".DiveDownloadService" android:process=":dc" android:exported="false" />`; the guard `find_violations(manifest_text) -> list[str]` and `check_file(path) -> (ok, lines)`.

- [ ] **Step 1: Write the failing guard self-test**

Create `scripts/check_dc_process_isolation_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for check_dc_process_isolation.py."""

import importlib.util
import io
import contextlib
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_dc_process_isolation",
    os.path.join(_HERE, "check_dc_process_isolation.py"),
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

GREEN = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.submersion.libdivecomputer">
    <application>
        <service
            android:name=".DiveDownloadService"
            android:process=":dc"
            android:exported="false" />
    </application>
</manifest>
"""

# Service present but NOT in its own process -> a native crash would kill the app.
RED_NO_PROCESS = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <service android:name=".DiveDownloadService" android:exported="false" />
    </application>
</manifest>
"""

RED_NO_SERVICE = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application />
</manifest>
"""


class GuardTests(unittest.TestCase):
    def test_green_has_no_violations(self):
        self.assertEqual(guard.find_violations(GREEN), [])

    def test_service_without_process_is_flagged(self):
        v = guard.find_violations(RED_NO_PROCESS)
        self.assertTrue(any("process" in x for x in v))

    def test_missing_service_is_flagged(self):
        v = guard.find_violations(RED_NO_SERVICE)
        self.assertTrue(any("DiveDownloadService" in x for x in v))

    def test_check_file_ok(self):
        fd, p = tempfile.mkstemp(suffix=".xml")
        with os.fdopen(fd, "w") as fh:
            fh.write(GREEN)
        self.addCleanup(os.unlink, p)
        ok, _ = guard.check_file(p)
        self.assertTrue(ok)

    def test_main_fails_on_red(self):
        fd, p = tempfile.mkstemp(suffix=".xml")
        with os.fdopen(fd, "w") as fh:
            fh.write(RED_NO_PROCESS)
        self.addCleanup(os.unlink, p)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = guard.main(["prog", p])
        self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 scripts/check_dc_process_isolation_test.py`
Expected: FAIL — `ModuleNotFoundError` / `No module named 'check_dc_process_isolation'` (the guard doesn't exist yet).

- [ ] **Step 3: Write the guard**

Create `scripts/check_dc_process_isolation.py`:

```python
#!/usr/bin/env python3
"""Verify the dive-download service stays isolated in its own process (#318).

The Android serial download runs libdivecomputer's native code, which can crash
with a native SIGSEGV. To keep such a crash from killing the app, the download
runs in a separate process declared as `android:process=":dc"`. A Java
try/catch cannot catch a native signal, so this process boundary IS the
containment; if it is dropped, the crash becomes fatal again. This guard fails
if the DiveDownloadService is missing or not in its own process. Pure stdlib.

Usage: check_dc_process_isolation.py <AndroidManifest.xml>
"""

import re
import sys

DEFAULT_MANIFEST = (
    "packages/libdivecomputer_plugin/android/src/main/AndroidManifest.xml"
)
SERVICE = "DiveDownloadService"


def find_violations(text):
    """Return a list of violation strings; empty == compliant."""
    # Match the <service ...> element (attributes may span lines).
    services = re.findall(r"<service\b[^>]*" + re.escape(SERVICE) + r"[^>]*>", text,
                          re.DOTALL)
    if not services:
        # Also handle the split android:name="....DiveDownloadService" form.
        if SERVICE not in text:
            return [f"{SERVICE} is not declared in the manifest"]
        services = re.findall(r"<service\b.*?>", text, re.DOTALL)
        services = [s for s in services if SERVICE in s]
        if not services:
            return [f"{SERVICE} is not inside a <service> element"]
    violations = []
    for svc in services:
        if 'android:process=":dc"' not in re.sub(r"\s+", " ", svc):
            violations.append(
                f"{SERVICE} is declared without android:process=\":dc\" -- a "
                "native download crash would kill the app (see issue #318)"
            )
    return violations


def check_file(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        violations = find_violations(fh.read())
    lines = [f"  FAIL  {v}" for v in violations]
    if not violations:
        lines.append(f"  ok    {SERVICE} runs in its own :dc process")
    return not violations, lines


def main(argv):
    paths = argv[1:] or [DEFAULT_MANIFEST]
    all_ok = True
    for path in paths:
        print(f"Checking dive-download process isolation: {path}")
        try:
            ok, lines = check_file(path)
        except OSError as exc:
            print(f"  ERROR reading {path}: {exc}")
            all_ok = False
            continue
        for line in lines:
            print(line)
        print("  -> PASS" if ok else "  -> FAIL: download is not process-isolated (#318)")
        all_ok = all_ok and ok
    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: Enable AIDL and declare the service**

In `packages/libdivecomputer_plugin/android/build.gradle`, inside the `android { }` block (e.g. right after `compileSdk = 34`), add:

```gradle
    buildFeatures {
        aidl true
    }
```

In `packages/libdivecomputer_plugin/android/src/main/AndroidManifest.xml`, add an `<application>` element containing the service (the plugin manifest currently has no `<application>`; add one — it merges into the app manifest):

```xml
    <application>
        <!-- Serial dive-computer downloads run here, in a separate process, so a
             native libdivecomputer SIGSEGV takes down only :dc, not the app (#318). -->
        <service
            android:name=".DiveDownloadService"
            android:process=":dc"
            android:exported="false" />
    </application>
```

(Place it as a sibling of the existing `<uses-feature>` elements, inside `<manifest>`.)

- [ ] **Step 5: Run the guard against the real manifest**

Run: `python3 scripts/check_dc_process_isolation.py packages/libdivecomputer_plugin/android/src/main/AndroidManifest.xml`
Expected: `-> PASS`. (`DiveDownloadService` doesn't exist as a class yet, but the manifest only names it; the guard checks the declaration.)

- [ ] **Step 6: Run the self-test to verify it passes**

Run: `python3 scripts/check_dc_process_isolation_test.py`
Expected: `OK` (5 tests).

- [ ] **Step 7: Wire into CI**

In `.github/workflows/ci.yaml`, in the `script-tests` job's "Run Python guard tests with coverage" step, add `scripts/check_dc_process_isolation.py` to the `guards=` list and append:

```yaml
          python3 -m coverage run --append --include="$guards" \
            scripts/check_dc_process_isolation_test.py
```

And add a source-check step near the existing "Check JNI local-reference hygiene" step:

```yaml
      - name: Check dive-download process isolation (manifest)
        run: python3 scripts/check_dc_process_isolation.py
```

- [ ] **Step 8: Commit**

```bash
git add scripts/check_dc_process_isolation.py scripts/check_dc_process_isolation_test.py \
        packages/libdivecomputer_plugin/android/build.gradle \
        packages/libdivecomputer_plugin/android/src/main/AndroidManifest.xml \
        .github/workflows/ci.yaml
git commit -m "feat(android): declare :dc download service + isolation guard (#318)"
```

---

## Task 2: `SerialDownloadRequest` parcelable

The immutable request the main process sends into `:dc`.

**Files:**
- Create: `packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/SerialDownloadRequest.aidl`
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRequest.kt`
- Test: `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/SerialDownloadRequestTest.kt`

**Interfaces:**
- Produces: `class SerialDownloadRequest(vendor: String, product: String, model: Long, name: String?, fingerprint: ByteArray?) : Parcelable`.

- [ ] **Step 1: Declare the parcelable for AIDL**

Create `.../aidl/com/submersion/libdivecomputer/SerialDownloadRequest.aidl`:

```aidl
package com.submersion.libdivecomputer;
parcelable SerialDownloadRequest;
```

- [ ] **Step 2: Write the Kotlin Parcelable**

Create `.../kotlin/com/submersion/libdivecomputer/SerialDownloadRequest.kt`:

```kotlin
package com.submersion.libdivecomputer

import android.os.Parcel
import android.os.Parcelable

/** The serial-download request marshaled from the main process into :dc. */
class SerialDownloadRequest(
    val vendor: String,
    val product: String,
    val model: Long,
    val name: String?,
    val fingerprint: ByteArray?,
) : Parcelable {

    constructor(parcel: Parcel) : this(
        vendor = parcel.readString() ?: "",
        product = parcel.readString() ?: "",
        model = parcel.readLong(),
        name = parcel.readString(),
        fingerprint = parcel.createByteArray(),
    )

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeString(vendor)
        dest.writeString(product)
        dest.writeLong(model)
        dest.writeString(name)
        dest.writeByteArray(fingerprint)
    }

    override fun describeContents(): Int = 0

    companion object CREATOR : Parcelable.Creator<SerialDownloadRequest> {
        override fun createFromParcel(parcel: Parcel) = SerialDownloadRequest(parcel)
        override fun newArray(size: Int): Array<SerialDownloadRequest?> = arrayOfNulls(size)
    }
}
```

- [ ] **Step 3: Write the round-trip test**

Create `.../androidTest/kotlin/com/submersion/libdivecomputer/SerialDownloadRequestTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import android.os.Parcel
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SerialDownloadRequestTest {
    @Test
    fun roundTripsThroughParcel() {
        val original = SerialDownloadRequest(
            vendor = "Mares", product = "Puck Pro", model = 0x18,
            name = "Puck Pro", fingerprint = byteArrayOf(1, 2, 3),
        )
        val parcel = Parcel.obtain()
        original.writeToParcel(parcel, 0)
        parcel.setDataPosition(0)
        val restored = SerialDownloadRequest.createFromParcel(parcel)
        parcel.recycle()

        assertEquals("Mares", restored.vendor)
        assertEquals("Puck Pro", restored.product)
        assertEquals(0x18L, restored.model)
        assertEquals("Puck Pro", restored.name)
        assertArrayEquals(byteArrayOf(1, 2, 3), restored.fingerprint)
    }

    @Test
    fun roundTripsNulls() {
        val original = SerialDownloadRequest("v", "p", 1, null, null)
        val parcel = Parcel.obtain()
        original.writeToParcel(parcel, 0)
        parcel.setDataPosition(0)
        val restored = SerialDownloadRequest.createFromParcel(parcel)
        parcel.recycle()
        assertEquals(null, restored.name)
        assertEquals(null, restored.fingerprint)
    }
}
```

(The androidTest infra — dependencies + test runner — is added in Task 3, Step 1. This test runs once that is in place.)

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/SerialDownloadRequest.aidl \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRequest.kt \
        packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/SerialDownloadRequestTest.kt
git commit -m "feat(android): SerialDownloadRequest parcelable for :dc IPC (#318)"
```

---

## Task 3: Dive marshaling + androidTest infra

Encode/decode `ParsedDive` to `byte[]` via the plugin's Pigeon codec. Sets up the instrumented-test infrastructure the IPC tests need.

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/build.gradle` (androidTest deps + runner)
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveMarshaling.kt`
- Test: `packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/DiveMarshalingTest.kt`

**Interfaces:**
- Consumes: `DiveComputerHostApi.codec` (public `MessageCodec<Any?>` from the generated Pigeon file); `ParsedDive` (Pigeon type).
- Produces: `object DiveMarshaling { fun encode(dive: ParsedDive): ByteArray; fun decode(bytes: ByteArray): ParsedDive }`.

- [ ] **Step 1: Add androidTest infrastructure**

In `packages/libdivecomputer_plugin/android/build.gradle`, add the instrumentation runner inside `defaultConfig { }`:

```gradle
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
```

Add an androidTest kotlin source dir inside `sourceSets { }` (next to the existing `main.java.srcDirs` line):

```gradle
        androidTest.java.srcDirs += "src/androidTest/kotlin"
```

Add to the `dependencies { }` block:

```gradle
    androidTestImplementation "androidx.test.ext:junit:1.1.5"
    androidTestImplementation "androidx.test:runner:1.5.2"
    androidTestImplementation "androidx.test:core:1.5.0"
```

- [ ] **Step 2: Write the failing marshaling test**

Create `.../androidTest/kotlin/com/submersion/libdivecomputer/DiveMarshalingTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DiveMarshalingTest {
    private fun sampleDive() = ParsedDive(
        fingerprint = "abcd",
        dateTimeYear = 2026, dateTimeMonth = 6, dateTimeDay = 30,
        dateTimeHour = 10, dateTimeMinute = 30, dateTimeSecond = 0,
        dateTimeTimezoneOffset = null,
        maxDepthMeters = 30.5, avgDepthMeters = 18.2, durationSeconds = 2400,
        minTemperatureCelsius = 12.0, maxTemperatureCelsius = 24.0,
        samples = listOf(
            ProfileSample(
                timeSeconds = 60, depthMeters = 5.0, temperatureCelsius = 22.0,
                pressureBar = 190.0, tankIndex = 0, heartRate = null, setpoint = null,
                ppo2 = null, cns = 0.0, rbt = null, decoType = null, decoTime = null,
                decoDepth = null, tts = null, o2Sensor1 = null, o2Sensor2 = null,
                o2Sensor3 = null, o2Sensor4 = null, o2Sensor5 = null, o2Sensor6 = null,
                gasMixIndex = 0,
            ),
        ),
        tanks = listOf(TankInfo(0, 0, 12.0, 200.0, 50.0)),
        gasMixes = listOf(GasMix(0, 32.0, 0.0)),
        events = listOf(DiveEvent(120, "gaschange", mapOf("mix" to "1"))),
        diveMode = "oc", decoAlgorithm = null, gfLow = null, gfHigh = null,
        decoConservatism = null, rawData = byteArrayOf(9, 8, 7), rawFingerprint = null,
        entryLatitude = null, entryLongitude = null, exitLatitude = null, exitLongitude = null,
    )

    @Test
    fun encodesAndDecodesBackToEqualDive() {
        val dive = sampleDive()
        val restored = DiveMarshaling.decode(DiveMarshaling.encode(dive))

        assertEquals(dive.fingerprint, restored.fingerprint)
        assertEquals(dive.maxDepthMeters, restored.maxDepthMeters, 0.0)
        assertEquals(dive.durationSeconds, restored.durationSeconds)
        assertEquals(1, restored.samples.size)
        assertEquals(5.0, restored.samples[0].depthMeters, 0.0)
        assertEquals(1, restored.tanks.size)
        assertEquals(12.0, restored.tanks[0].volumeLiters, 0.0)
        assertEquals("gaschange", restored.events[0].type)
        assertArrayEquals(byteArrayOf(9, 8, 7), restored.rawData)
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test packages/libdivecomputer_plugin` is NOT applicable (Kotlin). Instead:
Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:connectedDebugAndroidTest` (needs an emulator/device).
Expected: FAIL — `Unresolved reference: DiveMarshaling`.

- [ ] **Step 4: Write `DiveMarshaling`**

Create `.../kotlin/com/submersion/libdivecomputer/DiveMarshaling.kt`:

```kotlin
package com.submersion.libdivecomputer

import java.nio.ByteBuffer

/**
 * Encodes/decodes a ParsedDive to a byte[] using the plugin's OWN Pigeon codec
 * (via the public DiveComputerHostApi.codec), so a dive can cross the AIDL
 * boundary from :dc back to the main process without hand-duplicating the
 * 28-field, nested ParsedDive schema. The codec (StandardMessageCodec) already
 * knows how to write/read ParsedDive and its nested ProfileSample/TankInfo/
 * GasMix/DiveEvent types (type byte 136 and friends).
 */
object DiveMarshaling {
    fun encode(dive: ParsedDive): ByteArray {
        // StandardMessageCodec.encodeMessage returns a buffer positioned at the
        // end of the written data; flip to expose [0, size) for reading out.
        val buffer = DiveComputerHostApi.codec.encodeMessage(dive)
            ?: return ByteArray(0)
        buffer.flip()
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return bytes
    }

    fun decode(bytes: ByteArray): ParsedDive {
        val value = DiveComputerHostApi.codec.decodeMessage(ByteBuffer.wrap(bytes))
        return value as ParsedDive
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:connectedDebugAndroidTest`
Expected: PASS (`DiveMarshalingTest`, `SerialDownloadRequestTest`).

> If no emulator is available in this environment, mark this step "verify on emulator/device" and proceed — the Android build in CI compiles the code, and these instrumented tests are run on an emulator during verification (Task 10). Do not skip writing them.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/android/build.gradle \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveMarshaling.kt \
        packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/DiveMarshalingTest.kt
git commit -m "feat(android): ParsedDive<->byte[] marshaling for :dc IPC (#318)"
```

---

## Task 4: AIDL interfaces

The IPC contract between the main process and `:dc`.

**Files:**
- Create: `.../aidl/com/submersion/libdivecomputer/IDiveDownloadCallback.aidl`
- Create: `.../aidl/com/submersion/libdivecomputer/IDiveDownloadService.aidl`

**Interfaces:**
- Produces: `IDiveDownloadService` (`startSerialDownload`, `cancel`), `IDiveDownloadCallback` (`onProgress`, `onDive`, `onError`, `onComplete`).

- [ ] **Step 1: Write the callback interface**

Create `.../aidl/com/submersion/libdivecomputer/IDiveDownloadCallback.aidl`:

```aidl
package com.submersion.libdivecomputer;

// Called by :dc back into the main process as the download proceeds. `oneway`
// so the child never blocks on the main process, and a dead main-process
// binder can't wedge the child.
oneway interface IDiveDownloadCallback {
    void onProgress(int current, int max);
    void onDive(in byte[] pigeonEncodedDive);   // ParsedDive via DiveMarshaling
    void onError(String code, String message);
    void onComplete(long totalDives);
}
```

- [ ] **Step 2: Write the service interface**

Create `.../aidl/com/submersion/libdivecomputer/IDiveDownloadService.aidl`:

```aidl
package com.submersion.libdivecomputer;

import com.submersion.libdivecomputer.IDiveDownloadCallback;
import com.submersion.libdivecomputer.SerialDownloadRequest;

interface IDiveDownloadService {
    void startSerialDownload(in SerialDownloadRequest request, IDiveDownloadCallback callback);
    void cancel();
}
```

- [ ] **Step 3: Verify AIDL compiles**

Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:compileDebugAidl`
Expected: BUILD SUCCESSFUL (generates the `IDiveDownloadService.Stub`/`IDiveDownloadCallback.Stub` classes).

> If gradle isn't runnable here, this is verified by the CI Android build. Proceed.

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/IDiveDownloadCallback.aidl \
        packages/libdivecomputer_plugin/android/src/main/aidl/com/submersion/libdivecomputer/IDiveDownloadService.aidl
git commit -m "feat(android): AIDL contract for :dc download service (#318)"
```

---

## Task 5: `SerialDownloadRunner` (the moved serial download)

Runs in `:dc`. Adapts `performUsbSerialDownload` to emit through an `IDiveDownloadCallback` instead of `flutterApi`, and owns its own libdivecomputer session.

**Files:**
- Create: `.../kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`

**Interfaces:**
- Consumes: `IDiveDownloadCallback` (Task 4); `SerialDownloadRequest` (Task 2); `DiveMarshaling` (Task 3); existing `UsbSerialIoStream`, `LibdcWrapper`, `NativeTrace`, `LibdcWrapper.DownloadCallback`, `convertParsedDive` (move a copy — see Step 2), `LIBDC_TRANSPORT_SERIAL`, `LIBDC_STATUS_CANCELLED`.
- Produces: `class SerialDownloadRunner(context: Context) { fun run(request: SerialDownloadRequest, cb: IDiveDownloadCallback); fun cancel() }`.

- [ ] **Step 1: Create the runner by adapting `performUsbSerialDownload`**

Create `.../kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`. Start from a **verbatim copy** of `DiveComputerHostApiImpl.performUsbSerialDownload` (`DiveComputerHostApiImpl.kt:367-491`) and `convertParsedDive` (`DiveComputerHostApiImpl.kt:495-636`) and `decodeFingerprint` (`:259-262`), then apply these exact substitutions. This code runs on the binder thread inside `:dc`.

```kotlin
package com.submersion.libdivecomputer

import android.content.Context
import android.hardware.usb.UsbManager
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialProber

private const val RUNNER_LIBDC_TRANSPORT_SERIAL = 1 shl 0
private const val RUNNER_LIBDC_STATUS_CANCELLED = -10

/**
 * Runs the serial dive-computer download inside the :dc process. A native
 * SIGSEGV here kills only :dc; the main process detects it and reports an error
 * (see SerialDownloadClient). Adapted from DiveComputerHostApiImpl's in-process
 * serial download; emits results through the AIDL callback instead of Pigeon.
 */
class SerialDownloadRunner(private val context: Context) {

    @Volatile private var sessionPtr: Long = 0

    // Buffering across the multi-port probe, exactly as the in-process version:
    // dives accumulate while probing >1 adapter so a wrong port cannot leak
    // phantom dives; flushed on success, discarded on failure.
    private val diveBufferLock = Any()
    private var isBufferingDives = false
    private val bufferedDives = mutableListOf<ParsedDive>()

    fun cancel() {
        val ptr = sessionPtr
        if (ptr != 0L) LibdcWrapper.nativeDownloadCancel(ptr)
    }

    fun run(request: SerialDownloadRequest, cb: IDiveDownloadCallback) {
        NativeTrace.init(context)
        if (LibdcWrapper.loadError != null) {
            cb.onError("native_unavailable",
                "The dive-computer engine failed to load. Please update Submersion.")
            return
        }
        val session = LibdcWrapper.nativeDownloadSessionNew()
        if (session == 0L) {
            cb.onError("download_error", "Could not start a download session.")
            return
        }
        sessionPtr = session
        try {
            runProbe(request, session, cb)
        } finally {
            LibdcWrapper.nativeDownloadSessionFree(session)
            sessionPtr = 0
        }
    }

    private fun runProbe(request: SerialDownloadRequest, session: Long, cb: IDiveDownloadCallback) {
        val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
        val drivers: List<UsbSerialDriver> = usbManager?.let {
            UsbSerialProber.getDefaultProber().findAllDrivers(it)
        } ?: emptyList()

        if (drivers.isEmpty()) {
            cb.onError("no_serial_ports",
                "No USB serial ports found. Is the dive computer connected and powered on?")
            return
        }

        val fingerprintBytes = decodeFingerprint(request.fingerprint)
        val buffering = drivers.size > 1
        synchronized(diveBufferLock) { isBufferingDives = buffering; bufferedDives.clear() }

        val downloadCallback = object : LibdcWrapper.DownloadCallback {
            override fun onProgress(current: Int, maximum: Int) {
                cb.onProgress(current, maximum)
            }
            override fun onDive(divePtr: Long) {
                val parsed = convertParsedDive(divePtr)
                val buffered = synchronized(diveBufferLock) {
                    if (isBufferingDives) { bufferedDives.add(parsed); true } else false
                }
                if (!buffered) cb.onDive(DiveMarshaling.encode(parsed))
            }
        }

        val probeLog = StringBuilder()
        var anyOpened = false
        var lastResult = -1
        var lastErrorMsg = ""

        for (driver in drivers) {
            synchronized(diveBufferLock) { bufferedDives.clear() }
            val stream = UsbSerialIoStream(context, driver)
            val probeDev = driver.device
            NativeTrace.d(
                "probe ${driver.javaClass.simpleName} " +
                    "vid=0x${Integer.toHexString(probeDev.vendorId)} " +
                    "pid=0x${Integer.toHexString(probeDev.productId)} name=${probeDev.deviceName}"
            )
            if (!stream.open()) {
                NativeTrace.w("stream.open() failed for ${probeDev.deviceName}")
                probeLog.append("  ${probeDev.deviceName}: failed to open\n")
                continue
            }
            anyOpened = true
            val errorBuf = ByteArray(256)
            var thrownMsg: String? = null
            NativeTrace.d("nativeDownloadRun begin vendor=${request.vendor} product=${request.product} model=${request.model}")
            val result = try {
                LibdcWrapper.nativeDownloadRun(
                    session, request.vendor, request.product,
                    request.model.toInt(), RUNNER_LIBDC_TRANSPORT_SERIAL,
                    stream, request.name, fingerprintBytes, downloadCallback, errorBuf
                )
            } catch (e: Throwable) {
                NativeTrace.e("nativeDownloadRun threw: ${e.message}")
                thrownMsg = e.message
                -999
            }
            NativeTrace.d("nativeDownloadRun returned rc=$result")
            stream.close()
            lastResult = result
            lastErrorMsg = String(errorBuf).takeWhile { it.code != 0 }
                .ifEmpty { thrownMsg ?: "Download failed (rc=$result)" }
            if (result == 0 || result == RUNNER_LIBDC_STATUS_CANCELLED) break
            probeLog.append("  ${probeDev.deviceName}: download failed (rc=$result)\n")
        }

        val divesToFlush: List<ParsedDive> = synchronized(diveBufferLock) {
            val succeeded = lastResult == 0 || lastResult == RUNNER_LIBDC_STATUS_CANCELLED
            val list = if (succeeded) ArrayList(bufferedDives) else emptyList()
            bufferedDives.clear(); isBufferingDives = false; list
        }
        for (dive in divesToFlush) cb.onDive(DiveMarshaling.encode(dive))

        when {
            !anyOpened ->
                cb.onError("connect_failed", "No dive computer found. Ports tried:\n$probeLog")
            lastResult == 0 || lastResult == RUNNER_LIBDC_STATUS_CANCELLED ->
                cb.onComplete(divesToFlush.size.toLong())
            drivers.size > 1 ->
                cb.onError("connect_failed", "No dive computer found. Ports tried:\n$probeLog")
            else ->
                cb.onError("download_error", lastErrorMsg)
        }
    }

    private fun decodeFingerprint(fingerprint: ByteArray?): ByteArray? =
        fingerprint?.takeIf { it.isNotEmpty() }

    // convertParsedDive(divePtr: Long): ParsedDive is relocated here in Step 1a
    // (verbatim from DiveComputerHostApiImpl.kt:495-636).
}
```

- [ ] **Step 1a: Relocate `convertParsedDive` into the runner**

`convertParsedDive` reads the native dive through `LibdcWrapper` accessors and references no `flutterApi`/`mainHandler`, so it is pure and moves without changes. In your editor, copy `DiveComputerHostApiImpl.kt` **lines 495-636 verbatim** (the entire `private fun convertParsedDive(divePtr: Long): ParsedDive { ... }` method) and paste it as a private method of `SerialDownloadRunner`, replacing the placeholder comment above. Do not retype it — copy the exact source so accessor calls stay identical. (It remains in `DiveComputerHostApiImpl` too, since BLE still uses it in-process.)

**Substitutions applied vs the original `performUsbSerialDownload`:**
- `reportError(code, msg)` → `cb.onError(code, msg)`.
- `mainHandler.post { flutterApi.onDownloadProgress(DownloadProgress(...)) {} }` → `cb.onProgress(current, maximum)`.
- `mainHandler.post { flutterApi.onDiveDownloaded(dive) {} }` → `cb.onDive(DiveMarshaling.encode(dive))`.
- `mainHandler.post { flutterApi.onDownloadComplete(0, null, null) {} }` → `cb.onComplete(divesToFlush.size.toLong())`.
- Session lifecycle (`nativeDownloadSessionNew`/`Free`) moves in here (was in the main-process `performDownload`).
- `decodeFingerprint` now takes `ByteArray?` (the request already carries decoded bytes) — the hex-decode stays in the main process client (Task 7) OR pass raw bytes; here it just null-guards.
- `fingerprint` in `SerialDownloadRequest` is the already-decoded `ByteArray?` produced by the client.

> Replace the `TODO(...)` in `convertParsedDive` with the exact current body from `DiveComputerHostApiImpl.kt:495-636`. Leaving the `TODO()` is a task failure — paste the real code.

- [ ] **Step 2: Verify it compiles (via the Android build)**

Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:compileDebugKotlin`
Expected: BUILD SUCCESSFUL. (No unit test here — the runner needs USB hardware + the native lib; it is exercised by the instrumented isolation test in Task 9 and device verification in Task 10.)

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt
git commit -m "feat(android): SerialDownloadRunner (serial download inside :dc) (#318)"
```

---

## Task 6: `DiveDownloadService`

The bound service in `:dc` that drives `SerialDownloadRunner`, plus the debug crash-hook.

**Files:**
- Create: `.../kotlin/com/submersion/libdivecomputer/DiveDownloadService.kt`

**Interfaces:**
- Consumes: `IDiveDownloadService`, `SerialDownloadRunner`, `SerialDownloadRequest`, `IDiveDownloadCallback`.
- Produces: `class DiveDownloadService : Service()` bound via `IDiveDownloadService.Stub`. Debug crash-hook: if `request.vendor == "__crash_test__"`, deliberately dereference null natively to prove isolation.

- [ ] **Step 1: Write the service**

Create `.../kotlin/com/submersion/libdivecomputer/DiveDownloadService.kt`:

```kotlin
package com.submersion.libdivecomputer

import android.app.Service
import android.content.Intent
import android.os.IBinder
import java.util.concurrent.Executors

/**
 * Bound Service that runs the serial download in its OWN process (:dc, declared
 * in the manifest). A native SIGSEGV during the download kills only this
 * process; SerialDownloadClient (main process) sees the binder die and reports
 * an error. One download at a time.
 */
class DiveDownloadService : Service() {

    private val executor = Executors.newSingleThreadExecutor()
    @Volatile private var runner: SerialDownloadRunner? = null

    private val binder = object : IDiveDownloadService.Stub() {
        override fun startSerialDownload(
            request: SerialDownloadRequest,
            callback: IDiveDownloadCallback,
        ) {
            executor.execute {
                // Debug-only isolation proof: a reserved vendor triggers a real
                // native crash so tests can verify :dc dies without killing the app.
                if (request.vendor == CRASH_TEST_VENDOR) {
                    LibdcWrapper.nativeDebugCrash()
                    return@execute
                }
                val r = SerialDownloadRunner(applicationContext)
                runner = r
                try {
                    r.run(request, callback)
                } catch (t: Throwable) {
                    // Java-level failure (not a native crash): report, don't die.
                    try {
                        callback.onError("download_error",
                            "Download failed unexpectedly (${t.javaClass.simpleName}).")
                    } catch (_: Throwable) { /* main process gone */ }
                } finally {
                    runner = null
                }
            }
        }

        override fun cancel() {
            runner?.cancel()
        }
    }

    override fun onBind(intent: Intent?): IBinder = binder

    companion object {
        const val CRASH_TEST_VENDOR = "__crash_test__"
    }
}
```

- [ ] **Step 2: Add the native debug-crash hook**

The crash-test must be a *native* crash (a Java exception would be caught and would not prove native isolation). Add a JNI method. In `LibdcWrapper.kt`, add to the `external`/native declarations:

```kotlin
    /** Debug-only: deliberately crash the current process natively (issue #318
     *  isolation test). Never called outside the __crash_test__ path. */
    external fun nativeDebugCrash()
```

In `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`, add (near the other `Java_..._LibdcWrapper_*` functions):

```cpp
extern "C" JNIEXPORT void JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDebugCrash(JNIEnv *, jclass) {
    // Deliberate null dereference to raise SIGSEGV in :dc for the isolation test.
    volatile int *p = nullptr;
    *p = 42;
}
```

- [ ] **Step 3: Verify it compiles (Android build)**

Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:compileDebugKotlin`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveDownloadService.kt \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt \
        packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp
git commit -m "feat(android): DiveDownloadService (:dc host) + native crash-test hook (#318)"
```

---

## Task 7: `SerialDownloadClient` (main process)

Binds `:dc`, forwards the request, re-emits callbacks to `flutterApi`, and detects a child crash via `linkToDeath`.

**Files:**
- Create: `.../kotlin/com/submersion/libdivecomputer/SerialDownloadClient.kt`

**Interfaces:**
- Consumes: `IDiveDownloadService`, `IDiveDownloadCallback.Stub`, `SerialDownloadRequest`, `DiveMarshaling`, `DiveComputerFlutterApi`, `DownloadProgress`, `DiveComputerError`, `ParsedDive`.
- Produces: `class SerialDownloadClient(context: Context, flutterApi: DiveComputerFlutterApi) { fun start(request: SerialDownloadRequest); fun cancel() }`.

- [ ] **Step 1: Write the client**

Create `.../kotlin/com/submersion/libdivecomputer/SerialDownloadClient.kt`:

```kotlin
package com.submersion.libdivecomputer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Main-process client for the :dc download service. Binds the service, forwards
 * the request, re-emits its callbacks to Flutter via the existing Pigeon API,
 * and -- the whole point -- detects a :dc crash via linkToDeath and reports it
 * as a normal error so the app never dies. No in-process fallback.
 */
class SerialDownloadClient(
    private val context: Context,
    private val flutterApi: DiveComputerFlutterApi,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val inFlight = AtomicBoolean(false)
    private var service: IDiveDownloadService? = null
    private var pending: SerialDownloadRequest? = null

    private val deathRecipient = IBinder.DeathRecipient {
        // Fires when :dc dies (native SIGSEGV or OS kill) mid-download.
        onChildGone("The download process stopped unexpectedly — please try again.")
    }

    private val callback = object : IDiveDownloadCallback.Stub() {
        override fun onProgress(current: Int, max: Int) {
            postProgress(current, max)
        }
        override fun onDive(pigeonEncodedDive: ByteArray) {
            val dive = DiveMarshaling.decode(pigeonEncodedDive)
            mainHandler.post { flutterApi.onDiveDownloaded(dive) { } }
        }
        override fun onError(code: String, message: String) {
            finish()
            mainHandler.post {
                flutterApi.onError(DiveComputerError(code = code, message = message)) { }
            }
        }
        override fun onComplete(totalDives: Long) {
            finish()
            mainHandler.post { flutterApi.onDownloadComplete(totalDives, null, null) { } }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            binder ?: return
            try {
                binder.linkToDeath(deathRecipient, 0)
            } catch (_: Throwable) { /* already dead -> onServiceDisconnected handles it */ }
            val svc = IDiveDownloadService.Stub.asInterface(binder)
            service = svc
            val req = pending ?: return
            try {
                svc.startSerialDownload(req, callback)
            } catch (_: Throwable) {
                onChildGone("Could not start the download process.")
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            // Backup signal for a process death that didn't fire linkToDeath.
            onChildGone("The download process stopped unexpectedly — please try again.")
        }
    }

    fun start(request: SerialDownloadRequest) {
        if (!inFlight.compareAndSet(false, true)) return
        pending = request
        val intent = Intent(context, DiveDownloadService::class.java)
        val bound = try {
            context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        } catch (_: Throwable) { false }
        if (!bound) {
            // No in-process fallback: report and stop.
            inFlight.set(false)
            mainHandler.post {
                flutterApi.onError(DiveComputerError(
                    code = "download_error",
                    message = "Could not start the download process.")) { }
            }
        }
    }

    fun cancel() {
        try { service?.cancel() } catch (_: Throwable) { /* dying anyway */ }
    }

    private fun postProgress(current: Int, max: Int) {
        val progress = DownloadProgress(
            current = current.toLong(), total = max.toLong(), status = "downloading")
        mainHandler.post { flutterApi.onDownloadProgress(progress) { } }
    }

    private fun onChildGone(message: String) {
        // Only report if a download was actually in-flight (ignore benign unbind).
        if (!inFlight.compareAndSet(true, false)) { unbind(); return }
        unbind()
        mainHandler.post {
            flutterApi.onError(DiveComputerError(code = "download_crashed", message = message)) { }
        }
    }

    private fun finish() {
        inFlight.set(false)
        unbind()
    }

    private fun unbind() {
        val svc = service
        service = null
        pending = null
        try {
            svc?.asBinder()?.unlinkToDeath(deathRecipient, 0)
        } catch (_: Throwable) { }
        try {
            context.unbindService(connection)
        } catch (_: Throwable) { }
    }
}
```

- [ ] **Step 2: Verify it compiles (Android build)**

Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:compileDebugKotlin`
Expected: BUILD SUCCESSFUL.

(The crash-reaction path is exercised end-to-end by the instrumented test in Task 9. `onChildGone` uses `inFlight.compareAndSet(true,false)` so it fires exactly once and only when a download was active — the property that test asserts.)

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadClient.kt
git commit -m "feat(android): SerialDownloadClient with linkToDeath crash detection (#318)"
```

---

## Task 8: Delegate the serial path in `DiveComputerHostApiImpl`

Route serial/USB downloads to the client; keep BLE and discovery in-process. Cancel routing.

**Files:**
- Modify: `.../kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`

**Interfaces:**
- Consumes: `SerialDownloadClient` (Task 7); the existing hex-`decodeFingerprint`.
- Produces: unchanged Pigeon `startDownload`/`cancelDownload` behavior, now serial-isolated.

- [ ] **Step 1: Add the client field**

In `DiveComputerHostApiImpl`, next to the other fields (after `activeSerialStream` at line 43), add:

```kotlin
    private val serialDownloadClient = SerialDownloadClient(context, flutterApi)
    @Volatile private var serialDownloadActive = false
```

- [ ] **Step 2: Branch `startDownload` to the client for serial/USB**

Replace the body of `startDownload` (lines 162-186) with:

```kotlin
    override fun startDownload(
        device: DiscoveredDevice,
        fingerprint: String?,
        callback: (Result<Unit>) -> Unit
    ) {
        callback(Result.success(Unit))

        if (device.transport == TransportType.SERIAL || device.transport == TransportType.USB) {
            // Serial downloads run in the :dc process so a native crash can't kill
            // the app (issue #318). No in-process fallback.
            serialDownloadActive = true
            serialDownloadClient.start(
                SerialDownloadRequest(
                    vendor = device.vendor,
                    product = device.product,
                    model = device.model,
                    name = device.name,
                    fingerprint = decodeFingerprint(fingerprint),
                )
            )
            return
        }

        executor.execute {
            try {
                performDownload(device, fingerprint)
            } catch (t: Throwable) {
                NativeLogger.e(TAG, "LDC",
                    "download crashed: ${t.javaClass.simpleName}: ${t.message}")
                reportError("download_error",
                    "Download failed unexpectedly (${t.javaClass.simpleName}).")
            }
        }
    }
```

- [ ] **Step 3: Route cancel**

Replace `cancelDownload` (lines 188-192) with:

```kotlin
    override fun cancelDownload() {
        if (serialDownloadActive) {
            serialDownloadClient.cancel()
            return
        }
        if (downloadSessionPtr != 0L) {
            LibdcWrapper.nativeDownloadCancel(downloadSessionPtr)
        }
    }
```

- [ ] **Step 4: Remove the now-dead serial branch and helper (optional-but-clean)**

In `performDownload` (line ~214-221), the `TransportType.SERIAL, TransportType.USB ->` branch is now unreachable (serial is intercepted in `startDownload`). Replace that branch's body with a guard so it can't silently run in-process again:

```kotlin
            TransportType.SERIAL, TransportType.USB ->
                throw IllegalStateException(
                    "Serial downloads must run in :dc via SerialDownloadClient (#318)")
```

Leave `performUsbSerialDownload`, `makeDownloadCallback`, `convertParsedDive` in place for now (BLE reuses `makeDownloadCallback`/`convertParsedDive`; `performUsbSerialDownload` is dead but removing it is a separate cleanup — YAGNI for this task). `serialDownloadActive` stays true until the next download; set it false at the top of the BLE path and when starting BLE. Add at the start of the `else` (BLE) branch in `startDownload`: `serialDownloadActive = false`.

- [ ] **Step 5: Verify it compiles (Android build)**

Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:compileDebugKotlin`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt
git commit -m "feat(android): route serial downloads through :dc SerialDownloadClient (#318)"
```

---

## Task 9: Instrumented isolation test (the guarantee)

Proves that a native crash in `:dc` does NOT kill the app — on any emulator, no dive computer needed.

**Files:**
- Create: `.../androidTest/kotlin/com/submersion/libdivecomputer/DownloadIsolationTest.kt`

**Interfaces:**
- Consumes: `DiveDownloadService`, `IDiveDownloadService`, `IDiveDownloadCallback`, `SerialDownloadRequest`, `DiveDownloadService.CRASH_TEST_VENDOR`.

- [ ] **Step 1: Write the isolation test**

Create `.../androidTest/kotlin/com/submersion/libdivecomputer/DownloadIsolationTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class DownloadIsolationTest {

    @Test
    fun childCrashKillsOnlyServiceProcess_notThisTestProcess() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val died = CountDownLatch(1)

        val callback = object : IDiveDownloadCallback.Stub() {
            override fun onProgress(current: Int, max: Int) {}
            override fun onDive(pigeonEncodedDive: ByteArray) {}
            override fun onError(code: String, message: String) {}
            override fun onComplete(totalDives: Long) {}
        }

        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                binder ?: return
                // Detect :dc death (both signals).
                try {
                    binder.linkToDeath({ died.countDown() }, 0)
                } catch (_: Throwable) { died.countDown() }
                val svc = IDiveDownloadService.Stub.asInterface(binder)
                // Trigger the deliberate NATIVE crash inside :dc.
                svc.startSerialDownload(
                    SerialDownloadRequest(
                        DiveDownloadService.CRASH_TEST_VENDOR, "x", 0, null, null),
                    callback,
                )
            }
            override fun onServiceDisconnected(name: ComponentName?) { died.countDown() }
        }

        context.bindService(
            Intent(context, DiveDownloadService::class.java),
            connection, Context.BIND_AUTO_CREATE)

        // The child process must die (binder death observed) within a few seconds.
        assertTrue("expected :dc to die from the native crash",
            died.await(10, TimeUnit.SECONDS))

        // Crucially: THIS process is still alive and running assertions.
        // Reaching here at all proves the crash did not propagate.
        assertTrue(true)

        try { context.unbindService(connection) } catch (_: Throwable) {}
    }
}
```

- [ ] **Step 2: Run on an emulator/device**

Run: `cd packages/libdivecomputer_plugin/android && ../../../android/gradlew :libdivecomputer_plugin:connectedDebugAndroidTest`
Expected: PASS — the test process survives; `:dc` dies. (Check `adb logcat` shows the SIGSEGV tombstone for the `:dc` process, and the test run reports success.)

> Requires an emulator/device. If none is attached in this environment, mark "run during device verification (Task 10)". The test is the artifact that proves the guarantee; it must be written and committed now.

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/androidTest/kotlin/com/submersion/libdivecomputer/DownloadIsolationTest.kt
git commit -m "test(android): instrumented proof a :dc native crash spares the app (#318)"
```

---

## Task 10: Verification checklist (manual / device)

Not code — the verification steps that close out the feature. Record results in the PR.

- [ ] **Step 1: CI green**

Confirm on the PR: the Android build compiles (Kotlin + AIDL + native), the `script-tests` job runs `check_dc_process_isolation_test.py`, and the source guard step passes.

- [ ] **Step 2: Emulator — isolation proof**

On an emulator (no dive computer): run `connectedDebugAndroidTest`; confirm `DownloadIsolationTest` passes and `adb logcat` shows a `:dc` SIGSEGV tombstone while the app/test process stays alive. Confirm `DiveMarshalingTest` + `SerialDownloadRequestTest` pass.

- [ ] **Step 3: Emulator — the app survives a "crash" download**

Temporarily route a real download through the crash hook (or use the test), tap download in the app, and confirm the app shows a "download failed" error and remains fully usable (no restart to the launch screen).

- [ ] **Step 4: Hardware — Mares Puck Pro (reporter)**

On the reporter's Xiaomi 15T Pro + Puck Pro (a beta build): attempt the download. Two acceptable outcomes, both non-fatal — (a) it downloads, or (b) it reports "download failed" (with the `NativeTrace` breadcrumbs in `submersion.log` still identifying the crashing op). The app must NOT close.

- [ ] **Step 5: Regression — BLE unaffected**

On a BLE dive computer (or emulator BLE mock), confirm BLE download still works in-process, unchanged.

---

## Self-review notes

- **Spec coverage:** service+`:dc` (Task 1), AIDL (Task 4), `SerialDownloadRequest` (Task 2), marshaling via Pigeon codec (Task 3), `SerialDownloadRunner` (Task 5), `DiveDownloadService` (Task 6), `SerialDownloadClient` + `linkToDeath` + no-fallback (Task 7), delegation + cancel (Task 8), crash-hook + isolation test (Task 6/9), CI manifest guard (Task 1), device verification incl. Mares + BLE regression (Task 10). USB-permission-from-service risk is verified in Task 10 Step 4. Discovery/BLE stay in-process (Task 8).
- **Types consistent:** callback names `onProgress(int,int)`/`onDive(byte[])`/`onError(String,String)`/`onComplete(long)` are identical across the AIDL (Task 4), runner emits (Task 5), service (Task 6), and client stub (Task 7). `SerialDownloadRequest(vendor,product,model:Long,name:String?,fingerprint:ByteArray?)` identical across Tasks 2, 5, 7, 8, 9.
- **Known follow-ups (not this plan):** remove dead `performUsbSerialDownload` after burn-in; move BLE into `:dc`; the Subsurface-mirrored `read()` (functionality, separate).
