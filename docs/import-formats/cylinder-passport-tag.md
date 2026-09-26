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

Write the https form. From the release that adds scanning, and once the
website's app-link files are published, it opens Submersion directly when
installed and a browser page that shows the snapshot otherwise. Until then,
the tag is read by Submersion's own scanner and by pasting the link.

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

Example:

    https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-25&n=Steel+12+L&sn=AB12345&v=12&wp=232&m=st&vt=din&h=2024-06-14&vi=2026-03-02&oc=1

The gas mix is never on the tag. It changes every fill and travels in a fill
record instead.

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

The NDEF message holds, in order: the identity URI record above; when room
allows, the newest signed fill record as a second URI record
(`https://submersion.app/f#<token>`, documented separately); when room still
allows, an Android Application Record for `app.submersion`. Readers process
URI records in order and ignore records they do not know.

When a tag is too small, optional keys are dropped in this fixed order until
the record fits: `n`, `sn`, `vi`, `h`, `oc`, `vt`, `m`, `wp`, `v`. `f`, `p`
and `w` are never dropped. For the example above, a 144-byte NTAG213 drops
the name and serial and keeps the spec and dates; NTAG215 (504 bytes) and
NTAG216 (888 bytes) hold everything, and NTAG216 has room for the fill
record too. Names and serials are cut by whole characters, never mid-glyph.

## Printing

Error correction M. A printed or on-screen tag is at most 160 characters, a
version 9 code (53 modules), about half a millimetre per module on a 26 mm
label, which scans well with a phone camera. A tag that would run longer (a
long name in a script that percent-encodes to several characters per glyph)
drops optional keys in the NFC order above until it fits; the label prints
the name as text anyway.
