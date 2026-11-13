# Import dives from a Garmin watch over MTP on Windows

Release: v1.8.5

Issue: #4223 (follow-up to #1858)

## Intent

Submersion imports dives from a Garmin watch connected by cable, but only when
the watch mounts as a drive (`GarminDeviceDetector` scans drive letters D: to Z:
for `GARMIN\Activity`). Newer Garmins, among them the Descent G2 and Mk3,
connect as MTP devices instead. Windows Explorer lists them as a device
("Descent G2") with no drive letter, so the detector never sees them and the
diver has to copy the FIT files out by hand.

Garmin is also missing from Transfer > Dive Computers > Connect New Computer.
That list comes from libdivecomputer, which has no Garmin backend, so a diver
looking for their watch where every other computer lives finds nothing. The
#1858 reporter went there first, and so does anyone else.

On Windows, Submersion reads Garmin watches directly through Windows Portable
Devices (WPD), the operating system's own MTP stack, and offers that one
import from every place a diver looks for it: the Import page, the USB list
in Connect New Computer, and "Download" on a saved Garmin. All three run the
same import, and the dives flow through the existing FIT import.

## Goals

- On Windows, a Garmin connected over MTP (USB vendor ID `0x091E`) is detected
  alongside drive-mounted Garmins, and "Import from Garmin Device" appears for
  it on the Import page.
- On Windows, Connect New Computer's USB list includes Garmin as a
  manufacturer, with one entry, "Garmin watch (Descent, Fenix, Epix...)".
  Searching "garmin" or "descent" finds it. Picking it opens the Garmin
  device import instead of the libdivecomputer pair-and-download steps.
- On Windows, "Download" on a saved Garmin computer offers "Download from
  Watch" next to "Import from File" when a watch is connected, and runs the
  same import. To the diver it is a download, so the screen calls it one.
- The import copies the watch's `GARMIN/Activity/*.fit` files to a staging
  folder and hands that folder to the existing dive-FIT filter and batch flow,
  so parsing, computer matching, duplicate matching and review are unchanged.
- The Import page says which stage the import is at, with a progress bar:
  "Looking for the watch...", "Scanning Garmin Descent G2 activity..."
  (no count: WPD reports none while it lists a folder), "Reading watch
  files (n of N)..." and "Checking for dives (n of N)...". The last stage
  also shows for a drive-mounted watch.
- The staging folder is deleted when the wizard finishes or is reset, the same
  way ZIP expansion folders are.
- Every opening of the wizard reads the watch afresh. A Garmin import is not
  marked "loaded externally" (the drag-and-drop mark that makes the wizard
  keep its state on the next opening), since it always runs inside the
  wizard; with the mark, the next opening showed the last import's dives
  without reading the watch, even unplugged.

## Non-goals

- No other platform changes. macOS, Linux, Android and iOS keep their current
  behaviour, including no Garmin in the USB list. The new native code exists
  only in the Windows plugin.
- No libdivecomputer change, and no libmtp. Subsurface reaches the same files
  through its libdc fork's `garmin.c` and a libmtp-on-WPD shim; Submersion
  needs only "list and read files" and already has a fuller FIT parser
  (`FitParserService`) than libdc's.
- No Garmin download pipeline beside libdivecomputer's. Picking Garmin in
  Connect New Computer saves no USB address or connection; the computer is
  matched or created by the import from the FIT files' identity, as Garmin
  imports are today, and detection runs fresh each time.
- No per-model Garmin entries. The model comes from the FIT files, so a model
  list would offer a choice that changes nothing.
- No writing to the watch (no deleting imported activities, no clock sync).
- No incremental "only new files" cache in this release (see Open questions).

## Design

### Native layer (Windows plugin)

A separate Pigeon file, `packages/libdivecomputer_plugin/pigeons/garmin_mtp_api.dart`,
generates only the Dart and C++ outputs, so the shared
`dive_computer_api.dart` and the other platforms' generated code do not
change. On non-Windows platforms the channel is never registered, and the Dart
side never calls it (it checks the platform first).

```dart
class GarminMtpDevice {
  String id;            // WPD PnP device ID
  String friendlyName;  // "Descent G2"
  String? manufacturer;
  String? model;
  String? serialNumber;
}

class GarminMtpFile {
  String objectId;      // WPD object ID, valid for this connection
  String name;          // original file name, e.g. "2026-11-01-10-22-31.fit"
  int size;
  int? modifiedMillis;  // UTC
}

@HostApi()
abstract class GarminMtpHostApi {
  @async List<GarminMtpDevice> listDevices();
  @async List<GarminMtpFile> listActivityFiles(String deviceId);
  @async Uint8List readFile(String deviceId, String objectId);
}
```

`windows/garmin_mtp_host_api_impl.{h,cc}` implements it with WPD COM:

- Every call runs on a worker thread that calls `CoInitializeEx(MTA)` and
  posts its result back to the platform thread, using the same dispatch-window
  mechanism as `DiveComputerHostApiImpl::PostToPlatformThread`. The platform
  thread never blocks on the device.
- `listDevices`: `IPortableDeviceManager::GetDevices`, keep IDs whose PnP path
  contains `vid_091e` (case-insensitive), read friendly name, manufacturer and
  description from the manager, and the serial number from the device object's
  `WPD_DEVICE_SERIAL_NUMBER` once opened.
- `listActivityFiles`: open the device (`IPortableDevice::Open`, read-only
  client info), walk from `WPD_DEVICE_OBJECT_ID` through each storage object to
  a child folder named `GARMIN`, then `Activity` (names compared
  case-insensitively against `WPD_OBJECT_ORIGINAL_FILE_NAME`, falling back to
  `WPD_OBJECT_NAME`), and return its file children with name, size and
  modified date. A watch with several storages is searched in each.
- Object properties are read with one `IPortableDevicePropertiesBulk`
  request per folder, not one `GetValues` per object, which is what made
  listing a large Activity folder slow. An object the bulk request misses,
  or a device without bulk support, falls back to `GetValues`. The log
  line records how long the listing took.
- `readFile`: `IPortableDeviceResources::GetStream(objectId,
  WPD_RESOURCE_DEFAULT, STGM_READ)`, read the `IStream` in the
  optimal-buffer-size chunks it reports, and return the bytes.
- Errors (device unplugged, access denied because another app holds it) reach
  Dart as `FlutterError` with a stable code (`notFound`, `busy`, `ioError`)
  plus the HRESULT text.
- Links `PortableDeviceGuids.lib` and `Ole32.lib`, both in the Windows SDK;
  no new package.

This is written for Submersion, not copied from Subsurface's
`msvc_wpd.cpp`, which has no licence header and an unclear origin.

The C++ stays thin: no filtering, sorting or naming rules. Those live in Dart,
where CI tests them (native tests run on macOS CI; Windows CI only builds).

### Dart layer: reading the watch

- `lib/features/universal_import/data/services/garmin_mtp_source.dart`: an
  interface over the Pigeon API (`listDevices`, `listActivityFiles`,
  `readFile`) with the Pigeon-backed implementation and a fake for tests.
  Unavailable (empty device list) on anything but Windows.
- `GarminDevice` becomes a sealed class with two kinds: `GarminVolume`
  (today's case, with `activityDirPath`) and `GarminMtpWatch` (device ID,
  name, serial). `GarminDeviceDetector.detect()` returns both, volumes first.
  An MTP watch's files are not counted at detection, since listing them over
  MTP is slow and detection runs whenever the Import page opens. A failing
  MTP source never hides a mounted volume. Filtering on `vid_091e` should
  keep drive-mounted Garmins out of the MTP list, since Windows gives a
  mass-storage volume a `USBSTOR` WPD ID without the vendor ID; to confirm
  on a drive-mounting watch.
- `garminMtpSourceProvider` is the Pigeon-backed source on Windows and null
  everywhere else; the detector and notifier take it from there.
- `GarminMtpStager` copies a device's `.fit` files (filtered by name, the same
  rule as `listFitFiles`) into a fresh folder under `resolveSyncTempDir()`,
  reporting `(copied, total)` as it goes, and returns the folder path. A file
  that fails to read is skipped and counted, as an unreadable FIT is today.
- `UniversalImportNotifier.importFromGarminDevice()`: for an MTP device, stage
  first, register the staging folder with the wizard's temp-folder cleanup
  (the list ZIP expansion uses), then call the existing
  `_loadDiveFitsFromFolder` on it. The volume case is unchanged.

### Dart layer: the three entry points

All three call the same `importFromGarminDevice()`; none has its own reading
or parsing.

Entry points 2 and 3 open the import wizard at
`/transfer/import-wizard?source=garmin-device`
(`UniversalImportWizardRoute.garminDeviceImportLocation`). The route hands
the flag to `UniversalAdapter`, whose `resetState()` (run once as the wizard
opens) resets the import and then starts `importFromGarminDevice()`, once.

1. **Import page** (`file_selection_step.dart`): it already shows "Import
   from Garmin Device" whenever `garminDevicesProvider` finds a device, and
   MTP devices now count. The loading label shows the copy progress.
2. **Connect New Computer, USB tab** (`scan_step_widget.dart`):
   - `ScanStepWidget` takes an optional `onGarminWatchSelected`. With it, on
     Windows, the USB tab adds a Garmin entry (`GarminWatchUsbEntry`) to the
     map from `usbDevicesByManufacturerProvider`: a `DeviceModel` with a
     fixed id and no `dcModel`, whose model name is the localized label.
     It appears in the manufacturer dropdown and the grouped list like any
     other, and the existing search finds it: "garmin" through the
     manufacturer, "descent" through the label. The provider itself is
     unchanged.
   - Tapping it does not call `onDeviceSelected` (which leads to pairing and a
     libdivecomputer download). `DcAdapterScanStep` pushes the Garmin import
     location. When no watch is connected, the import's existing "not found"
     message tells the diver to connect it by cable.
   - This is the only branch in the discovery flow that bypasses
     libdivecomputer, and it is decided once, at the tap.
3. **Saved Garmin, Download** (`dc_no_direct_download_view.dart`): on Windows,
   when `garminDevicesProvider` finds a watch, the title becomes "Download
   dives from {name}", "Download from Watch" becomes the main action and
   "Import from File" moves to a secondary, outlined one (`DcMessageLayout`
   gains an optional secondary action). With no watch connected, the title
   is "Connect {name} to download its dives" and the body asks for the watch
   by USB rather than a manual copy of GARMIN/Activity. Other platforms keep
   "Can't download this computer directly".

### Text

New l10n strings, added to every ARB file:

- The USB list entry: "Garmin watch (Descent, Fenix, Epix...)".
- Progress, one per stage: "Looking for the watch...", "Scanning {device}
  activity..." (the name prefixed with "Garmin" unless it has it), "Reading
  watch files ({copied} of {total})...", "Checking for dives ({checked} of
  {total})...".
- `universalImport_error_garminBusy`: "The Garmin device is in use by another
  app. Close Garmin Express and try again."
- The saved-Garmin screen: "Download dives from {name}", "Download from
  Watch" and the body shown with them; "Connect {name} to download its
  dives" and its body for an unplugged watch.

`universalImport_error_garminNotFound` stays as it is. The Dive Computers help
note (`diveComputer_list_helpGarminNote`) gets a Windows variant saying Garmin
watches can be added from Connect New Computer.

## Testing

- Dart unit tests (TDD), all against the fake source, with paths built with
  `p.join`:
  - The detector lists volumes then MTP watches, and a failing MTP source
    still lists the volumes.
  - The stager copies only `.fit` files, reports progress, skips a failing
    read, and creates its folder under the resolved temp root.
  - The notifier stages, registers cleanup, and reaches the batch flow with
    only dive FITs. Busy and not-found errors map to their messages.
- Widget tests:
  - The Garmin entry appears in the USB list and dropdown on Windows only,
    and is found by "garmin" and "descent".
  - Tapping it starts the Garmin import and never calls `onDeviceSelected`.
  - The saved-Garmin view shows "Download from Watch" only when a watch is
    detected, and never says it can't download a Garmin on Windows.
- Native: Windows CI's `flutter build windows` proves it compiles. Behaviour is
  checked by hand on a real Garmin over MTP on Windows 11 (the maintainer of
  this change has one):
  - detection, and a full import from each of the three entry points;
  - re-import showing the dives as duplicates;
  - unplugging mid-copy;
  - Garmin Express running at the same time.
- PR screenshots, at phone and desktop widths:
  - the USB list with the Garmin entry;
  - the Import page with the Garmin action for an MTP watch;
  - the progress state;
  - the saved-Garmin view with the new action.

## Open questions

- **Speed.** If copying the whole Activity folder over MTP turns out slow on a
  watch with years of activities, a follow-up can keep a per-device cache of
  already-copied files (keyed by serial number, file name and size) so each
  import reads only new files. That decision waits for numbers from the real
  device.
