# Emergency Tag Format

**Status:** Format version 1.
**Spec:** `docs/design/specs/2026-11-27-emergency-tag-design.md`.

An emergency tag is an NFC tag (or a printed card) that a diver carries on their gear so that anyone helping them, such as a boat crew, paramedics or a hospital, can read their medical details, emergency contacts and dive insurance from the tag itself, with their own phone. The reader does not need Submersion.

## NDEF message

The tag holds one NDEF message of one or two records, in this order:

1. **The first record**, which a phone acts on when the tag is tapped. The diver chooses one of:
   - **Link:** a well-known URI record holding the emergency link (below). iPhones and Android phones open it in the browser, where `submersion.app/e` shows the details. It needs a network connection to load the page.
   - **Call:** a well-known URI record holding `tel:<number>`, one of the diver's emergency contacts or their insurer's 24-hour assistance line. Any phone offers to call it, with no network and no app.
2. **The text record:** a well-known text record (`T`, UTF-8, the language code of the app's language), with the same details as plain text. NFC reader apps on both platforms show it, with no network. A call tag always has it. A link tag may leave it out, so the link has the whole tag.

There is no Android Application Record: the tag is meant for the reader's browser, dialler or reader app, never for Submersion.

## Link

    https://submersion.app/e#<payload>

The payload sits in the fragment, so a browser never sends it to the server. Readers match the scheme and host in any case, accept `www.submersion.app`, and require the path to be exactly `/e`.

### Payload

A query string of short keys in this order, values percent-encoded as in a URL query (`+` for a space).

| Key | Meaning | Example |
| --- | --- | --- |
| `f` | format version | `1` |
| `w` | date the tag was written, `YYYY-MM-DD` | `2026-11-27` |
| `n` | the diver's name | `Sam+Diver` |
| `y` | year of birth | `1984` |
| `al` | allergies | `Penicillin` |
| `me` | medications | `None` |
| `bt` | blood type | `O%2B` |
| `mn` | medical notes | `Asthma+as+a+child` |
| `c1` | emergency contact 1: name | `Alex+Diver` |
| `r1` | emergency contact 1: relation | `Partner` |
| `p1` | emergency contact 1: phone | `%2B15551234567` |
| `c2`, `r2`, `p2` | emergency contact 2, as for contact 1 | |
| `in` | insurer | `DAN` |
| `ip` | insurance policy number | `1234567` |
| `il` | insurer's 24-hour assistance line | `%2B19196849111` |
| `t` | `1` when fields were left off to fit the tag | `1` |

Only `n` is required; `f` defaults to `1`. A reader ignores keys it does not know, and shows a key it knows but cannot read as missing.

## Text record

Plain text, one item per line, labels in the language of the diver's app. The order puts what a responder needs first:

    EMERGENCY INFO
    Name: Sam Diver (born 1984)
    Allergies: Penicillin
    Emergency contact: Alex Diver (Partner) +1 555 123 4567
    Emergency contact: ...
    Insurance: DAN, policy 1234567, 24h line +1 919 684 9111
    Medications: None
    Blood type: O+
    Medical notes: Asthma as a child
    Written 2026-11-27 with Submersion
