# Media Sync: Manual Device Test Checklist

The hardware pass for the media sync program
(`2026-09-18-media-sync-program-design.md`, section 8). Every item below is
already covered by a two-device harness scenario, cited in brackets; this
pass proves the same behaviour on real devices, real photo libraries and
real stores, which the harness can only fake. All items passing on hardware
is the exit criterion for the tracking issue (#2090). It also closes #425
once the reporter confirms, and #1625 once it reproduces and passes on
Android.

## Before you start

- [ ] A. Every device runs a build from `main` that includes every slice
      (slice 9, #2313, is the last code change). Check the build number on
      each device; a mixed fleet tests the old code.
- [ ] B. Every device in a pair syncs to the same Cloud Sync backend and
      has run Sync Now at least once, so each knows the other's name
      (Settings > Cloud Sync, troubleshooting, "Devices on this backend").
- [ ] C. Media storage is attached on every device of the pair
      (Settings > Media Storage), to the same store. The store named in
      the pair's heading comes first; repeat the pair on the second store.
- [ ] D. Wi-Fi, not cellular, unless the item says otherwise: the upload
      policy holds large originals for Wi-Fi.

**When an item fails,** before changing anything, capture on the device
that shows the problem: the row's diagnostics (open the photo, the info
panel, Copy diagnostics) and the whole-library report (Settings > Media
Storage > Export media report). Attach both to the item's issue. The
report lists file paths and device names; nothing is sent anywhere.

## Verification status

Fill in as items pass, with the build, the date and who ran it.

- Mac and iPhone, iCloud store: not run.
- Mac and iPhone, S3 store: not run.
- Android and Windows, S3 store: not run.
- Android and Windows, Google Drive store: not run.
- Linux peer, S3 store: not run.

## Pair 1: Mac and iPhone sharing iCloud Photos

Store: iCloud, then S3. Both devices signed in to the same Apple ID with
iCloud Photos on, and the test photos fully synced to both libraries
(visible in Photos on each) before linking.

- [ ] 1.1 Gallery photo, Mac to iPhone [S5, S0]. On the Mac, link a photo
      from the library to a dive. Sync Now on the Mac, then on the iPhone.
      The photo shows on the iPhone within one render. Its info panel reads
      "Linked on" the Mac's name, never "Missing from this device".
- [ ] 1.2 Gallery photo, iPhone to Mac. The same in the other direction.
- [ ] 1.3 Burst pair [S6]. Shoot a burst (or two photos in the same
      second) on the iPhone, let iCloud Photos sync it, and link two frames
      to a dive on the iPhone. On the Mac, after Sync Now, each tile shows
      its own frame (compare against Photos), not the same frame twice and
      not a placeholder. Diagnostics for each row show cache method
      `cloud_id`.
- [ ] 1.4 Older links learn their cloud id [slice 8 backfill]. Link a photo
      on a build from before slice 8, then update both devices. After a
      Sync Now on the linking device and then the peer, the peer resolves
      the photo, and its diagnostics show a cloud id on the row.
- [ ] 1.5 Video [S0]. Link a video from the library on one device, let it
      upload (Settings > Media Storage > Transfers reaches zero), Sync Now
      on both. The peer shows the video's poster and plays it from the
      store.
- [ ] 1.6 Check all on the peer [S2]. On the iPhone, Settings > Media
      Sources > Check all media, on a library that shows correctly. The
      result counts no updated items for photos that were fine, and a Sync
      Now afterwards publishes no media changes (the Cloud Sync page shows
      nothing pending for media).
- [ ] 1.7 Delete a dive on the peer. Delete, on the iPhone, a dive with
      photos linked on the Mac. Sync Now on both. The dive and its media
      rows are gone on the Mac. The photos themselves are untouched in
      Photos on both devices; dive photos are links only.
- [ ] 1.8 Stamps that did not arrive [S4]. On the Mac, link a file (not a
      gallery photo) and let it upload. On the iPhone, sync once so the row
      arrives; if the upload stamps arrive in the same pull, this item is
      covered by 1.5 and can be skipped. A row whose stamps are still
      missing shows from the store anyway, with no sync write from the
      iPhone (nothing pending afterwards).

## Pair 2: Android and Windows

Store: S3, then Google Drive.

- [ ] 2.1 Gallery photo from Android [S5]. Link a photo from the Android
      gallery to a dive and let it upload. On Windows, after Sync Now, the
      photo shows from the store. Windows opens no file dialog for it.
- [ ] 2.2 File from Windows [S0]. Link a file from disk on Windows and let
      it upload. On Android, after Sync Now, it shows from the store, and
      its info panel names the Windows device as where it was linked.
- [ ] 2.3 Limited access on Android [S7]. On Android 14 or later, set the
      app's photo access to "Allow limited access" and leave a linked photo
      out of the selection. Its tile reads "Not in your allowed photos";
      nothing reads "File not found", and after Check all media the row is
      not flagged missing (on this device or, after a sync, on Windows).
      Open the photo: the viewer offers "Allow full access" and "Choose
      photo again".
- [ ] 2.4 Choose photo again. From 2.3, tap Choose photo again, add the
      photo in the system sheet, and return: the photo shows without
      leaving the viewer.
- [ ] 2.5 Allow full access. From 2.3, tap Allow full access, grant full
      access in the system settings, and switch back to the app: the photo
      shows on return.
- [ ] 2.6 No prompt from browsing. Reset the app's photo permission to
      "ask every time" (or reinstall), sync a library with gallery photos
      from the other device, and scroll the dive photos. No OS permission
      prompt appears until you open the photo picker or tap Allow full
      access.
- [ ] 2.7 A moved file [#1625]. Link a file (not a gallery photo) on
      Android, then move it to another folder with a file manager. The
      photo still shows (found in the library by name and time) or, if the
      system no longer indexes it, reads as unavailable; it never becomes
      "Missing from this device" after Check all media.
- [ ] 2.8 An OS re-index [#1625]. With photos linked on Android, clear the
      data of Android's own media provider (Settings > Apps, show system
      apps, "Media Storage", which is the system app, not this app's page of
      the same name), or restore from a backup, so Android re-indexes the
      library. Linked photos come back without relinking,
      and none is flagged missing.
- [ ] 2.9 Kill mid-upload [S10]. Link a large video on Android and, while
      Transfers shows it uploading, force-stop the app. Relaunch: the
      transfer resumes or restarts on its own within a minute, without
      tapping anything, and completes.
- [ ] 2.10 A waiting queue says why [S8]. On Windows, queue an upload (link
      a large file) and turn networking off before it finishes. Settings >
      Media Storage > Transfers says "Waiting for a connection", not a bare
      count. Turn networking back on: the upload resumes by itself, with no
      restart and no tap.
- [ ] 2.11 A store the devices disagree on is paused, with the reason. On
      Windows, reconnect media storage to a different store while Android
      stays on the first. Settings > Media Storage shows "Transfers paused"
      and says the device and the cloud no longer agree on the store.
      Reconnecting to the store the cloud holds resumes transfers.

## Pair 3: Linux as a pure peer

Store: S3. Linux links nothing; every row comes from the other devices.

- [ ] 3.1 Every foreign row reads from the store [S0, S4]. After Sync Now,
      every photo and video linked on the other devices and uploaded shows
      on Linux. Rows not yet uploaded read "From" the linking device's name,
      never "File not found".
- [ ] 3.2 No file dialog. Scroll the whole library and open several photos:
      no file-open dialog appears at any point. Only the photo picker opens
      one, and only when you ask it to.
- [ ] 3.3 The health report exports. Settings > Media Storage > Export
      media report writes a file through the share sheet (or the save
      dialog), and the file lists every row with its verdict. The debug log
      export (the Debug Logs page, with debug mode on) includes the same
      report.

## Reporter follow-ups

- [ ] R1. #425 (iCloud linked photos not found). After pair 1 passes, ask
      the reporter to retest on the current build and attach Copy
      diagnostics for one photo linked on each device. Close #425 when they
      confirm (spec 6.4).
- [ ] R2. #1625 (media not available on Android). After 2.3 to 2.8 pass,
      ask the reporter for Copy diagnostics on one affected photo on the
      current build. Close #1625 when it reproduces as fixed (spec 6.3,
      section 10).
- [ ] R3. Close the tracking issue #2090 when every pair above has passed
      on at least one store and R1 and R2 are settled or waiting only on a
      reporter.
