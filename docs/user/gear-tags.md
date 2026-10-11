# Gear Tags

Put a QR label or an NFC tag on any piece of gear (a regulator, a BCD, a dive
computer, a drysuit) and scanning it opens that item's gear passport.
Cylinders have their own, richer passport; see
[Cylinder Passports](cylinder-passports.md).

## The gear passport

Open an item in Equipment and tap **Open passport** on its **Gear passport**
card. The passport shows, on one page:

- **The item:** name, type, brand and model, serial, and the owner when
  another diver profile's gear is shared with you.
- **Service clocks:** what maintenance is due, with **Log service**.
- **Recent service:** the newest three service records. **See all** opens the
  full history on the item's page.
- **Exposure:** how many dives and hours the item has been used.
- **Location** and **Trips:** where the item is stored, and the trips it is
  packed for.
- **Tag:** the QR code, and the label and NFC actions below.

Items with the Wanted status have no tag.

## Labels and tags

A tag is a link, `https://submersion.app/g#...`, that carries the item's
identity and a snapshot of its name, brand, model, serial and last service
date. You can carry it two ways:

- **QR label.** **Print label** on the **Tag** card makes a PDF label. To
  print labels for several items at once, select them in the Equipment list
  and choose **Print labels**; cylinders and other gear can be mixed in one
  sheet. Labels suit fins, masks and suits, where an NFC chip is awkward.
- **NFC tag.** **Write NFC tag** writes the link to a tag you hold against the
  back of the phone, then reads it back to check it. An NTAG213 holds the
  identity, type and name; an NTAG215 or NTAG216 holds everything. When a
  small tag cannot hold everything, the sheet says which details were left
  off. Writing needs a phone with NFC.

A tag already on the item can be attached with **Link an existing tag** by
pasting its link.

A tag is a snapshot. When the item is serviced, renamed or retyped after the
tag was written, the **Tag** card says so and offers **Rewrite tag** or
**Reprint label**.

## Scanning a tag

Point the camera at the label (iOS, Android and macOS), tap an NFC tag
(phones with NFC), or paste the tag's link. Where you scan decides what
happens:

- **Equipment list, Scan a tag:** your own item opens its passport; a
  cylinder opens its cylinder passport.
- **Dive editor, Equipment section, Scan:** your own item is added to the
  dive's gear, with its components, just as if you picked it.
- **Trip, Gear tab, Add, Scan a tag:** your own item is packed for the trip;
  a cylinder joins the trip's cylinder board.

**Someone else's gear** (a rental regulator, a club BCD) opens a read-only page
with what the tag says. **Add to my gear** adds it to your Equipment; its last
service date becomes the starting point of its service clocks. In the dive
editor and on a trip, a tag that is not yours says so, with **View** to open
that page.

Scanning a tag with a phone camera outside the app opens Submersion directly
where it is installed. Without the app, the link opens a page on
submersion.app that shows what the tag says. The tag's details sit after the
`#` in the link, so the browser never sends them to the website.

## The tag format

The tag format is public. The
[Gear Tag Format](https://github.com/submersion-app/submersion/blob/main/docs/developer/reference/formats/gear-tag.md)
describes every field.

## See also

- [Equipment](equipment.md): service clocks, locations and the rest of your gear
- [Cylinder Passports](cylinder-passports.md): tags, fills and spec for cylinders
- [Trips](trips.md): packing gear for a trip
