# Cylinder passports 1b: device checklist

**Issue:** #2335
**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`

Everything here needs real hardware; CI runs none of it. Record the device,
OS version and build for each line.

## Prerequisites

- Apple developer portal: Associated Domains enabled for `app.submersion`,
  provisioning profiles regenerated.
- submersion.app serves `/.well-known/apple-app-site-association` (paths
  `/c`, `/c/*`) and `/.well-known/assetlinks.json` (release and debug
  signing fingerprints).
- A printed passport label and its link copied to the clipboard.

## Camera scanning

- [ ] iPhone: Equipment, menu, "Scan a cylinder tag", allow the camera, point
      at an own cylinder's label: its passport opens, once.
- [ ] Android: the same.
- [ ] macOS: the same with the built-in camera.
- [ ] macOS Developer ID DMG (unsandboxed, hardened runtime): the camera
      starts and a label scans.
- [ ] Deny the camera permission: the sheet shows the unavailable message and
      the paste field still opens a tag.
- [ ] A label at 25 mm scans from about 15 cm.

## Links

- [ ] iPhone, app closed: tap `https://submersion.app/c#...` in Notes: the app
      launches on that cylinder's passport.
- [ ] iPhone, app open: the same link opens the passport once.
- [ ] Android, app closed and open: the same two checks.
- [ ] `submersion://c?...` from Notes (iOS) and a messaging app (Android).
- [ ] macOS: open `submersion://c?...` from a browser address bar.
- [ ] Fresh install with no diver: tap a label link; finish setup; the
      passport opens after the wizard, not over it.
- [ ] Google sign-in and the Lightroom connection still complete (their
      callbacks must not be caught by the passport link handling).

## Foreign passport

- [ ] Scan a tag that is not in your gear: the read-only passport shows the
      snapshot and "As written on the tag on <date>".
- [ ] "Use on a dive": a new dive opens with that cylinder as tank 1.
- [ ] "Add to my gear": the cylinder appears in Equipment with hydro and VIP
      baselines from the tag, and its passport opens.

## Dive editor

- [ ] Edit a dive, open tank 1, tap the scan icon, scan an own cylinder: the
      spec and newest mix fill in and the cylinder appears in the dive's gear.
- [ ] Imperial units: the filled volume and pressure show in cuft and psi.
