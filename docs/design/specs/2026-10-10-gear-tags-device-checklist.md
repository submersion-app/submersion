# Gear tags: device checklist

**Issue:** #2652
**Spec:** `docs/design/specs/2026-10-10-gear-tags-and-passports-design.md`

Everything here needs real hardware; CI runs none of it. Record the device,
OS version, build and tag model for each line.

## Prerequisites

- One each of NTAG213 and NTAG215, blank.
- A regulator and a tank in Equipment, a second diver profile's shared BCD,
  and an upcoming trip.
- The website's `apple-app-site-association` lists `/g` and `/g/*`, and the
  static `/g` page is live (for the background and browser lines).

## Write

- [ ] iPhone: regulator, Open passport, Tag card, Write NFC tag on an NTAG215:
  written, every field kept.
- [ ] Android: the same.
- [ ] NTAG213: written, with "Left off to fit" naming the last service date
  and model for a typical name.
- [ ] Print label for the regulator, and Print labels for a mixed selection
  (regulator, tank, fins): one PDF, the gear labels with a `/g` QR.

## Read

- [ ] iPhone and Android, app open: Equipment, Scan a tag, tap the regulator's
  tag: its gear passport opens.
- [ ] Camera scan of the printed regulator label on iPhone, Android and
  macOS: the gear passport opens.
- [ ] Windows: Scan a tag, paste the label's link: the gear passport opens.
- [ ] Android, app closed: tap the regulator's tag: the app opens on its gear
  passport.
- [ ] iPhone, app closed, website live: tap the tag: the app opens on its gear
  passport.
- [ ] A tag written before the last service: the Tag card says the tag is out
  of date.

## Scan into a dive and a trip

- [ ] Dive editor, Equipment, Scan, the regulator's tag: the regulator joins
  the dive's gear with its components; a second scan says it is already on
  this dive.
- [ ] The same with the tank's cylinder tag: the tank joins the gear list.
- [ ] Small phone (360 px wide) in German: the Equipment header shows its
  actions as icons with tooltips, none cut off.
- [ ] Trip, Gear, Add, Scan a tag, the regulator: packed. The tank's tag: a
  slot on the cylinder board.

## Someone else's gear

- [ ] A tag written for another diver's regulator: the read-only page shows
  type, name, brand and model, serial and last service.
- [ ] Add to my gear: a regulator is created with those details; its service
  clocks start from the last service date; no service record appears.
- [ ] The same tag scanned in the dive editor: "Not in your gear" with View.

## Older apps

- [ ] A 1.8.1 build taps a `/g` tag: the app does not open it as a cylinder
  (Android: the browser opens the website page instead).
- [ ] A phone without the app scans the label: the website's `/g` page shows
  the snapshot and store links.
