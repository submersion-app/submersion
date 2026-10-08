# Cylinder passports 3: the fill on the tag, device checklist

**Issue:** #2337
**Spec:** `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md`, section 11

Everything here needs real hardware; CI runs none of it. Record the device,
OS version, build and tag model for each line.

## Prerequisites

- Two phones, each with its own Submersion library (not synced with each
  other), one iPhone and one Android if possible.
- One NTAG213 and one NTAG215, blank.
- A tank in the first phone's gear with a passport.

## Write the fill

- [ ] iPhone: Passport, Current fill, Log a fill, save: "Fill logged" asks
      to write it to the tank's tag; Write to tag, hold the NTAG215: "The
      newest fill is on the tag too".
- [ ] Android: the same.
- [ ] Not now closes the dialog and writes nothing.
- [ ] NFC turned off in the system settings: saving a fill asks nothing.
- [ ] NTAG213: the write succeeds without the fill, and the sheet names
      "Newest fill" as left off; the NTAG215 carries it.
- [ ] The Tag card's Write NFC tag carries the newest fill too; its printed
      label does not.

## Read the fill

- [ ] Second phone, app closed, the tank added to its gear with the same
      passport id (Link existing tag): tap the tag: the passport opens and
      says "Fill from the tag added", with the mix and pressure; the fill
      shows a "From tag" chip and "Analyse the gas yourself before you dive
      it".
- [ ] Tap the tag again: nothing more is added.
- [ ] The first phone: tap the tag: nothing is added (the fill is already
      its own).
- [ ] Second phone: delete that fill, tap the tag: it stays deleted.
- [ ] Two phones on the same synced library: log a fill with notes on the
      first, write the tag, tap it on the second before it has synced, then
      sync both: the first phone's fill keeps its notes and is not marked
      "From tag".
- [ ] Dive editor, a tank, Scan tag with the tag: the fill joins the
      history and the tank takes its mix.
- [ ] A buddy's tank (not in your gear): the foreign passport shows "Last
      fill on the tag" with the mix, pressure, date and who filled it; Use
      on a dive prefills that mix. Nothing is stored.
- [ ] A phone without Submersion: the tag opens the web page, which shows
      the last fill and the note to analyse it.
- [ ] An older app build (before this change) reading a tag with a fill:
      the passport opens normally.

## Trimix blender

- [ ] Choose cylinder, a tank from your gear: the cylinder size and the
      last fill's mix (as what is already in it) fill in; the start pressure
      is unchanged. Close and reopen the blender: they are still there.
- [ ] Choose cylinder, Scan tag, your own tank's tag: the same tank. A
      buddy's tag: "That cylinder is not in your gear".
- [ ] Log this fill, choose the tank: Log a fill opens with the target mix,
      target pressure and settled temperature, and "Enter your analysed
      values" under O2. Change O2 to the analysed value, save, Write to tag:
      the tag carries the blend's fill with the analysed O2.
- [ ] Phone width: the Cylinder card's Choose cylinder and the Fill
      procedure's Log this fill fit without clipping, in English and German.
