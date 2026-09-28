# Cylinder passports 2: NFC device checklist

**Issue:** #2336
**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`

Everything here needs real hardware; CI runs none of it. Record the device,
OS version, build and tag model for each line.

## Prerequisites

- Apple developer portal: NFC Tag Reading enabled for `app.submersion`,
  provisioning profiles regenerated.
- One each of NTAG213, NTAG215 and NTAG216, blank; one locked tag; one tag
  holding another app's link.

## Write

- [ ] iPhone: Passport, Tag card, Write NFC tag, hold an NTAG216: "Tag
      written and checked", the type and capacity, "Everything fits".
- [ ] Android: the same.
- [ ] NTAG213: written, with "Left off to fit" naming the dropped fields.
- [ ] Locked tag: "This tag is locked", nothing written.
- [ ] Lift the tag mid-write: "The tag was not written", Try again writes
      it cleanly.
- [ ] iPhone: dismiss the system sheet: the write sheet closes, no error.

## Read

- [ ] iPhone and Android: Equipment, Scan a cylinder tag, Tap an NFC tag:
      the passport opens.
- [ ] The other app's tag: "That is not a cylinder tag", the sheet stays.
- [ ] Android with NFC off: the button is disabled with "NFC is turned off".
- [ ] iPad without NFC: disabled with "This device cannot read or write".

## Background launch

- [ ] Android, app closed: tap a written tag: Submersion opens on that
      cylinder's passport.
- [ ] Android, app open on another screen: tap: the passport opens once.
- [ ] iPhone, app closed, website app-link files live: tap: the passport
      opens.
- [ ] Fresh install with no diver: tap: the passport opens after setup.

## Stale tag

- [ ] Log a hydro after writing a tag, then scan it: the stale hint shows
      Rewrite and Reprint; Rewrite writes the new dates, Reprint opens the
      label.
