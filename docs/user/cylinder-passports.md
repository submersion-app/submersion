# Cylinder Passports

Every cylinder in your gear has a passport: one page in the app with its spec,
its service dates, its current fill and every fill you have logged. Put a QR
label or an NFC tag on the cylinder and anyone with a phone can scan it to see
what the cylinder is; an NFC tag can also carry its newest fill.

> [!NOTE]
> **Where to find it:** open a Tank item in **Equipment** and tap
> **Open passport** on its **Cylinder passport** card. A cylinder's passport exists as
> soon as the item does; there is nothing to create.

## What a passport holds

| Card | Shows |
|------|-------|
| **Cylinder** | Volume, working pressure, material and valve, the free gas the cylinder holds at its working pressure, and its buoyancy empty and full |
| **Current fill** | The newest fill: O2 and He, fill pressure, when and where it was filled, the analyzer and gas temperature, and the mix's MOD and END |
| **Service** | The last hydrostatic test and visual inspection, and O2 cleaning once you choose **Track O2 cleaning** |
| **Trips** | The trip the cylinder is packed for. **Pack for a trip** puts it on that trip's cylinder board |
| **Fill history** | Every fill you have logged, and how many since the last hydro |
| **Tag** | The cylinder's QR code, and buttons to print a label or write an NFC tag |

Service dates come from the cylinder's service clocks (see
[Equipment](equipment.md)), so logging a hydro or a visual inspection there
updates the passport too.

> [!WARNING]
> When the last fill is richer than your high-O2 line (40% oxygen unless you
> change it in **Settings > Safety > Equipment condition**) and the cylinder has
> no O2 cleaning on record (neither a logged O2 clean nor a baseline date on its
> O2 clean clock), or its O2 cleaning is overdue, the passport shows a warning
> banner. A passport records what was written down; analyse the gas
> yourself before you dive it.

## Logging a fill

Tap **Log a fill** on the **Current fill** card and enter the date and time,
the O2 and He you analysed, the fill pressure, and optionally the gas
temperature, fill station, analyzer and notes. The fill becomes the cylinder's
current fill and joins its history.

On a dive, open a tank and tap **Fill from my cylinders** to copy a cylinder's
size and newest fill into the tank. See [Logging Dives](dive-logging.md).

## Labels and tags

A tag is a link, `https://submersion.app/c#...`, that carries the cylinder's
identity and a snapshot of its spec and service dates. You can carry it two
ways:

- **QR label.** **Print label** on the **Tag** card makes a PDF label to print
  and stick on the cylinder. To print labels for several cylinders at once,
  select them in the Equipment list and choose **Print labels**. A printed
  label never includes a fill, since the fill changes every time.
- **NFC tag.** **Write NFC tag** writes the link to a tag you hold against the
  back of the phone, then reads it back to check it. Each write includes the
  newest fill, so rewrite the tag after a fill. Use an NTAG215 or NTAG216
  tag; when a small tag cannot hold everything, the sheet says which details
  were left off. Writing needs a phone with NFC.

A tag already on the cylinder (one a shop wrote, for example) can be attached
with **Link an existing tag** by pasting its link.

A tag is a snapshot. When the cylinder's spec or service dates change after the
tag was written, the **Tag** card says so and offers **Rewrite tag** or
**Reprint label**.

## Scanning a tag

Choose **Scan a cylinder tag** from the menu on the Equipment list, or tap the
scan button on a tank in the dive editor. Point the camera at the label (iOS,
Android and macOS), tap an NFC tag (phones with NFC), or paste the tag's link.

- **Your own cylinder** opens its passport. If the tag carries a fill that is
  not in its history yet, it is added, once.
- **Someone else's cylinder** opens a read-only page with what the tag says,
  including the last fill when the tag carries one.
  From there, **Add to my gear** adds it to your Equipment, and
  **Use on a dive** starts a new dive with a tank filled in from the tag.

Scanning a tag with a phone camera outside the app opens Submersion directly
where it is installed. Without the app, the link opens a page on
submersion.app that shows what the tag says and links to the app. The tag's
details sit after the `#` in the link, so the browser never sends them to the
website.

## The tag format

The tag format is public, so dive shops and gas analyzer makers can print or
write tags of their own. The
[Cylinder Passport Tag Format](https://github.com/submersion-app/submersion/blob/main/docs/developer/reference/formats/cylinder-passport-tag.md)
describes every field.

## See also

- [Equipment](equipment.md): service clocks and the rest of your gear
- [Logging Dives](dive-logging.md): tanks, and filling one from your cylinders
- [Trips](trips.md): packing cylinders for a trip
