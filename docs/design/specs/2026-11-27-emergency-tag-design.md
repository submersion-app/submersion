# Emergency Tag Design

- **Issue:** [#5060](https://github.com/submersion-app/submersion/issues/5060)
- **Format:** [Emergency Tag Format](../../developer/reference/formats/emergency-tag.md)

## Goal

A diver writes their emergency details to an NFC tag on their gear, or prints them on a card, so that whoever helps them after a rescue can read them with their own phone when the diver is unconscious and their phone is lost, locked or dead.

## Decisions the maintainer made

- **The tag's first record is the diver's choice:** a `submersion.app/e` link, which any phone opens as a readable page but which needs a network, or a `tel:` link, which any phone offers to call with no network. A plain-text record with the same details always follows.
- **With the call option, the diver picks the number:** emergency contact 1 (the default), emergency contact 2 or the insurer's 24-hour assistance line.
- **A website `/e` page** shows the link's details in the browser, without sending them to the server. It ships in a companion PR to `submersion-website`, and the site does not list `/e` in its app-link files, so the link always opens in the browser.
- **The text record is optional on a link tag:** a switch, on by default, lets the diver leave it off so the link has the whole tag and fits more details. A call tag always carries the text, since that is the only place its details are.
- **First PR scope:** choosing the fields, the preview, the size check, writing the tag, and a printable card (PDF). An on-screen QR code, locking the tag and an out-of-date reminder are left for later.

## Why two records

iPhones read an NDEF tag without an app only through a URI record (https, tel, sms, mailto and a few others), and use the first one. They show nothing for a text or vCard record. Android shows a text record without an app when the text is all the tag holds, and opens the first URI otherwise. No single record reaches every phone offline, so the first record serves the phone's built-in reader and the text record serves everyone with an NFC reader app.

## What the diver sees

An **Emergency tag** action on the emergency card page opens the emergency tag page:

1. A short explanation and a warning that anyone who taps the tag can read everything on it, at any time, until it is rewritten or removed.
2. **When tapped:** "Open a web page" or "Call a number", and with the call option a choice of number from those recorded. With the web page option, a switch "Also write the details as plain text" (on by default).
3. **What to include:** a switch per field (name, year of birth, allergies, medications, blood type, medical notes, emergency contact 1 and 2, insurance). A field with nothing recorded is shown off and disabled, with "Not recorded". The choices are saved on the diver's row and sync with it.
4. **Preview:** the text record exactly as it will be written, and the size: about how many bytes it takes and which common tag sizes (NTAG213 144 bytes, NTAG215 504, NTAG216 888) hold it whole.
5. **Write NFC tag**, through the shared tag write sheet, which reports the tag type, its capacity and any field left off to fit. It is hidden where the device has no NFC, and disabled with the reason when NFC is off.
6. **Print card**, a PDF through the share sheet.

### Defaults

Every field with a value starts on, except medical notes and year of birth, which start off: medical notes are free text and the most likely to overflow a tag, and a year of birth helps identify the diver but is not needed to treat them. Nothing is written until the diver has seen the preview and pressed Write, so the defaults are a starting point, never a disclosure on their own.

## Fitting a small tag

When the message does not fit the tag, fields come off both records together, in this order: medical notes, year of birth, emergency contact 2, policy number, medications, blood type, insurance, allergies, emergency contact 1. The name and the first record are never dropped. The link then carries `t=1`. If even the name and the first record do not fit, the write reports the tag as too small.

## Printable card

An A4 page with a 105 x 148 mm (A6) card outlined with a dashed cut line: "EMERGENCY INFO" in large red type, the same lines as the text record, and a QR code of the first record. The card works with no phone at all; the QR code gives a phone the same link or number the tag does. Nothing is left off to fit the card.

## Storage

`divers.emergency_tag_share`, nullable `TEXT` holding JSON (schema v388): the first-record choice, the call target, whether a link tag carries the text, and a switch per field. Null means the defaults. It syncs with the diver row, appears in the sync conflict catalogue and in the diver profile document agents read, as `buddy_card_share` does.

## Not in scope

- Hosting the details online: the tag carries them.
- Changing the buddy card, which still never offers medical, insurance or emergency details.
- An on-screen QR code, locking the tag, and reminding the diver to rewrite the tag when the details change.
