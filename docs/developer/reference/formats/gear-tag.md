# Gear Tag Format

**Status:** Format version 1.
**Spec:** `docs/design/specs/2026-10-10-gear-tags-and-passports-design.md`, section 6.

A gear tag is one short string, printed as a QR code or written to an NFC tag
as an NDEF URI record. Scanning it in Submersion opens that item's gear
passport: its service status, recent service, usage, location and trips. It
covers every kind of equipment except cylinders, which carry a
[Cylinder Passport Tag](cylinder-passport-tag.md) instead. The format is
public so shops and clubs can produce their own tags.

## URL forms

The written form is always

    https://submersion.app/g#<payload>

Submersion also accepts `submersion://g?<payload>`, and the payload in either
the fragment or the query of both forms. Readers match the scheme and host in
any case, accept `http` and a `www.submersion.app` host, and require the path
to be exactly `/g`; any other path or host is not a gear tag. Unlike the
cylinder tag there is no bare-payload form: a bare query string is read as a
cylinder tag. The payload sits in the fragment so a browser never sends it to
the server.

Write the https form. It opens Submersion directly where the app is
installed, once the website's app-link files list `/g`, and a browser page
that shows the snapshot otherwise. Submersion's own scanner (the Equipment
list's menu, the dive editor's Equipment section and a trip's Gear tab) and
pasting the link work without the website.

## Payload

A query string of short keys in this order, values percent-encoded as in a
URL query (`+` for a space). All dates are local calendar dates.

| Key | Meaning | Example |
| --- | --- | --- |
| `f` | format version | `1` |
| `p` | passport id, a UUID, lower case | `8f3a5c1e-1b2c-4d5e-8f90-1234567890ab` |
| `w` | date the tag was written, `YYYY-MM-DD` | `2026-10-10` |
| `t` | equipment type, as Submersion names it | `firstStage` |
| `n` | name, at most 40 characters | `Apeks+XTX50+primary` |
| `b` | brand, at most 24 characters | `Apeks` |
| `mo` | model, at most 24 characters | `XTX50` |
| `sn` | serial number, at most 24 characters | `AB12345` |
| `ls` | date of the newest service of any kind, `YYYY-MM-DD` | `2026-03-02` |

`p` and `t` are required; `f` defaults to `1`. The types are the names of
Submersion's equipment types, such as `regulator`, `firstStage`,
`secondStage`, `bcd`, `wing`, `drysuit`, `computer`, `transmitter`, `fins`,
`mask`, `light` and `other`. `tank` is not allowed: a cylinder's tag is a
cylinder tag.

A worked example:

    https://submersion.app/g#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-10-10&t=firstStage&n=Apeks+XTX50+primary&b=Apeks&mo=XTX50&sn=AB12345&ls=2026-03-02

## Passport ids

Submersion mints a passport id the first time an item's gear passport is
opened, its label printed or its tag written: a UUID version 5 of the item's
own id, so two devices that mint before they sync agree. A cylinder's id is
minted the same way. Any UUID version is accepted on a tag, which lets a shop
write its own ids; **Link an existing tag** on the item attaches one.

## Reading rules

- Unknown keys are ignored, so a future format still opens in an older app.
- `f` greater than 1 opens with a "newer format" note.
- A missing or malformed `p`, a missing `t`, or `t=tank` rejects the tag.
  Compare ids case-insensitively.
- A `t` this version does not know opens as plain "Gear"; adding it to the
  diver's equipment makes it type Other.
- Unparseable dates are dropped, not trusted. Text is cut by whole
  characters, never mid-glyph.
- Everything on the tag except `p` is a snapshot from `w`; Submersion compares
  it with the live record and reports a stale tag when a service was logged
  after `w`, the type changed, or the name, brand, model or serial differ.
  A key the tag left off is not a difference.

## NFC layout

The NDEF message holds, in order: the identity URI record above; when room
still allows, an Android Application Record for `app.submersion`. Readers
process URI records in order and ignore records they do not know.

When a tag is too small, optional keys are dropped in this fixed order until
the identity record fits: `ls`, `mo`, `b`, `sn`, `n`. `f`, `p`, `w` and `t`
are never dropped. For the example above an NTAG213 (about 137 bytes of NDEF
message) drops `ls` and `mo` and has no room for the Android record;
NTAG215 and NTAG216 hold everything. Every write is read back before
Submersion reports it as written.

## Printing

Error correction M, as for cylinder labels. A printed or on-screen tag is at
most 160 characters; a longer one (a long name in a script that
percent-encodes to several characters per glyph) drops optional keys in the
NFC order above until it fits, and the label prints the name as text anyway.
