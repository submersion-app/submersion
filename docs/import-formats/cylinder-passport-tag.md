# Cylinder Passport Tag Format

**Status:** Format version 1.
**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`, section 6.

A cylinder passport tag is one short string, printed as a QR code or written
to an NFC tag as an NDEF URI record. Scanning it in Submersion opens that
cylinder's passport. Anyone may print or write these tags; the format is
public so shops and analyzer makers can produce them.

## URL forms

The written form is always

    https://submersion.app/c#<payload>

Submersion also accepts `submersion://c?<payload>`, and the payload in either
the fragment or the query of both forms. Readers match the scheme and host in
any case, accept `http` and a `www.submersion.app` host, and require the path
to be exactly `/c`; any other path or host is not a tag. The payload sits in
the fragment so a browser never sends it to the server.

Write the https form. It opens Submersion directly where the app is
installed, once the website's app-link files are published, and a browser
page that shows the snapshot otherwise. Submersion's own scanner (the
Equipment list's menu, and each tank in the dive editor) and pasting the link
work without the website.

## Payload

A query string of short keys in this order, values percent-encoded, all
metric. Only `f` and `p` are required.

| Key | Meaning | Example |
| --- | --- | --- |
| `f` | format version | `1` |
| `p` | passport id, a UUID, lower case | `8f3a5c1e-1b2c-4d5e-8f90-1234567890ab` |
| `w` | date the tag was written, `YYYY-MM-DD` | `2026-09-25` |
| `n` | name or identifier, at most 40 characters | `Steel+12+L` |
| `sn` | stamped serial, at most 24 characters | `AB12345` |
| `v` | volume, litres, up to one decimal, 0.5 to 50 | `12` |
| `wp` | working pressure, bar, integer, 50 to 400 | `232` |
| `m` | material: `al`, `st`, `cf` | `st` |
| `vt` | valve: `din`, `yoke`, `conv` | `din` |
| `h` | last hydrostatic test, `YYYY-MM-DD` | `2024-06-14` |
| `vi` | last visual inspection, `YYYY-MM-DD` | `2026-03-02` |
| `oc` | `1` when oxygen clean at write time | `1` |
| `fi` | newest fill: its id, a UUID, the dedupe key | `3f0c2b8e-...` |
| `ft` | fill time, RFC 3339 UTC to the second | `2026-09-28T09:30:00Z` |
| `fo` | fill O2, percent | `32.1` |
| `fh` | fill He, percent, default 0 | `0` |
| `fp` | fill pressure, bar | `232` |
| `fc` | gas temperature at the reading, C | `24.5` |
| `fb` | filled by (a person or a station), at most 40 characters | `Blue+Hole` |
| `fa` | analyzer, at most 40 characters | `Divesoft` |
| `fs` | reserved for a future signature; ignored | |

Example:

    https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-25&n=Steel+12+L&sn=AB12345&v=12&wp=232&m=st&vt=din&h=2024-06-14&vi=2026-03-02&oc=1

## The newest fill

An NFC tag also carries the cylinder's newest fill, in the `f` keys above.
Printed labels never do: a label outlives many fills, and a stale mix on a
label is worse than none. Submersion writes the fill whenever it writes the
tag, including straight after Log a fill and after the blender's Log this
fill.

A fill needs `fi`, `ft` as an RFC 3339 time (`T`, seconds, and `Z` or an
offset) that names a real date and time, and `fo` greater
than 0, with `fo` plus `fh` at most 100. A fill missing any of those, or
with a malformed one, is dropped on its own: the tag still opens.
Out-of-range details (`fp` over 400 bar, `fc` outside -40 to 80 C) are
dropped and the fill kept. `fs` is reserved and ignored; nothing on a tag is
signed, so a reader must present the fill as what the tag says, for the
diver to analyse, never as verified.

When the diver who owns the cylinder scans the tag, Submersion adds the fill
to the cylinder's history once, keyed by `fi`: a fill already there, or one
the diver deleted, is not added again. Anyone else's scan shows the fill
without storing it.

Example, an NFC tag with a fill:

    https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-28&v=12&wp=232&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09%3A30%3A00Z&fo=32.1&fh=0&fp=232&fc=24.5&fb=Blue+Hole&fa=Divesoft

## Passport ids

Submersion mints `p` as a UUID version 5 of the cylinder's equipment id, so
two devices that create the same cylinder's tag before they sync arrive at
the same id. A tag linked from another source keeps the id it was printed
with. Readers must treat `p` as an opaque identifier and must not try to
derive anything from it; third-party producers may use any UUID version.

## Reading rules

- Unknown keys are ignored, so a future format still opens in an older app.
- `f` greater than 1 opens with a "newer format" note.
- A missing or malformed `p` rejects the tag. Any UUID version is accepted;
  compare ids case-insensitively.
- Out-of-range numbers and unparseable dates are dropped, not trusted.
- Everything on the tag except `p` is a snapshot from `w`; Submersion compares
  it with the live record and reports a stale tag.

## NFC layout

The NDEF message holds, in order: the identity URI record above, with the
newest fill riding in the passport link itself; when room still allows, an
Android Application Record for `app.submersion`. Readers process URI records
in order and ignore records they do not know.

When a tag is too small, optional keys are dropped in this fixed order until
the identity record fits: the fill's `fa`, `fb` and `fc`, then the whole
fill, then `n`, `sn`, `vi`, `h`, `oc`, `vt`, `m`, `wp`, `v`.
`f`, `p` and `w` are never dropped. Submersion fits the message to the NDEF
capacity the phone reports for the tag (about 137 bytes on an NTAG213, 496
on an NTAG215 and 868 on an NTAG216), and adds the Android Application
Record only when it still fits. For the first example above an NTAG213 drops
the name and serial and has no room for the Android record, keeping the
spec and dates, and a fill never fits on it; NTAG215 and NTAG216 hold
everything, a fill included, and are the tags to buy. Every write is read back before Submersion reports it as
written. Names and serials are cut by whole characters, never mid-glyph.

## Printing

Error correction M. A printed or on-screen tag is at most 160 characters, a
version 9 code (53 modules), about half a millimetre per module on a 26 mm
label, which scans well with a phone camera. A tag that would run longer (a
long name in a script that percent-encodes to several characters per glyph)
drops optional keys in the NFC order above until it fits; the label prints
the name as text anyway.
