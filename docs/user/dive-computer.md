# Dive computers

Download your dives straight from a dive computer over Bluetooth or USB. Submersion reads the full profile &mdash; depth, temperature, tank pressure, gas mixes, decompression data, and more &mdash; and turns each recorded dive into a log entry, no cables-to-a-PC step required.

> [!NOTE]
> **Where to find it:** There is no separate "Dive Computers" screen buried in Settings. You reach dive computers two ways: tap the **+** button on the **Dives** list and choose **Import from Computer**, or open the **Transfer** tab (in the main navigation) and use the **Dive Computers** section. Both lead to the same place &mdash; a list of computers you have used, plus a button to connect a new one.

<!-- screenshot: images/dive-computer/discover.png — device discovery -->

## Supported computers and connections

Submersion talks to dive computers through **libdivecomputer**, the same open-source engine behind Subsurface and other dive-log tools. That gives broad coverage across the major brands &mdash; **Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi**, and many more models from other makers. If your computer is in libdivecomputer's device library, Submersion can download from it.

Connections fall into three types:

| Connection | Best for | Notes |
|------------|----------|-------|
| **Bluetooth LE** | Most modern computers | The default for current Shearwater, Garmin, Suunto, Mares, and Pelagic-based models. Used on phones, tablets, and desktops. |
| **Bluetooth Classic** | Older Bluetooth models | An earlier Bluetooth standard some legacy computers use. |
| **USB** | Desktop only | A wired connection for computers that download over a cable or IrDA-to-USB clip. Available on macOS, Windows, and Linux &mdash; not on phones. |

When you scan, Submersion shows a **Bluetooth** tab and a **USB** tab. The Bluetooth tab discovers nearby devices live; the USB tab lists supported models grouped by manufacturer so you can pick yours and connect the cable.

> [!TIP]
> Each discovered Bluetooth device is tagged. A **Supported** badge means the model is in libdivecomputer's library and should download automatically; a **Known** badge means you have already paired and downloaded from it before.

## Connecting a computer for the first time

1. Put your dive computer into its transfer or Bluetooth mode. Every brand does this differently, so check your computer's manual &mdash; the app cannot wake the device for you.
2. Start the connect flow: **Dives &rarr; + &rarr; Import from Computer**, or **Transfer &rarr; Dive Computers &rarr; Connect new computer**.
3. **Scan.** On the **Bluetooth** tab, wait for your computer to appear, then tap it. (For a wired computer, switch to the **USB** tab, pick the model, and connect the cable.)
4. **Confirm.** Give the computer a name you will recognise &mdash; for example, "My Perdix". A **Recognized Device** badge confirms Submersion knows how to talk to it. Tap **Connect & Download**.
5. **Download.** Submersion connects and pulls in your dives, showing progress as it goes.

After the first successful download, the computer is saved to your list so future downloads take a single tap.

### Entering a BLE PIN code

Some Bluetooth computers &mdash; notably **Aqualung and Apeks models built on the Pelagic chipset** (i300R, i330R, i470TC, i770R, Apeks DSX, and similar) &mdash; require a one-time PIN to pair. When one is needed, the computer shows a six-digit code on its own screen and Submersion pops up a **PIN Code Required** dialog. Type the code shown on the computer and tap connect.

> [!TIP]
> You normally only enter the PIN once per device. Submersion securely remembers the access code it derives from your PIN, so later downloads connect without asking again. If the computer is factory-reset, it will simply ask for a new PIN.

## Downloading dives

Once a computer is saved, download from it by tapping it in your list (or the **download** icon next to it) and confirming. The download screen shows a progress ring, the current status, and each dive as it arrives.

<!-- screenshot: images/dive-computer/download-progress.png — download in progress -->

### New dives only vs. a full re-download

By default Submersion downloads **only the dives added since your last download**. It does this with libdivecomputer's fingerprint mechanism: after each successful import it remembers the newest dive, and on the next download the computer stops sending as soon as it reaches that point. This keeps downloads fast even on a computer that stores hundreds of dives.

- The **first** download from a computer always pulls **everything** &mdash; there is no previous point to stop at.
- If there is genuinely nothing new, you will see **No new dives to download &mdash; all dives from this computer have already been imported.**
- To pull every dive again from scratch &mdash; for example after a problem, or to recover dives you deleted in the app &mdash; open the computer's detail page and choose **Re-import all dives**. This option appears only once the computer has a saved download history.

> [!WARNING]
> A full re-download of a computer with a large dive history can take several minutes. Keep the computer awake and within range for the whole transfer.

### Staying on the download screen

A download holds an open Bluetooth connection, so leaving the screen mid-transfer would silently abandon it. If you press back, switch tabs, or close the screen while a download is running, Submersion asks first:

> **Download in Progress** &mdash; Leaving will cancel the current download from your dive computer.

Choose **Stay** to keep downloading, or **Leave** to cancel and navigate away. You can also stop a download yourself at any time with the **Cancel** button on the progress screen.

## After a download

### Duplicate detection

Submersion checks every downloaded dive against the dives already in your log so the same dive does not appear twice. Matching uses the computer's own dive fingerprint plus a comparison of start time, depth, and duration, with a tolerance for small clock drift between devices. Each match is rated by confidence (exact, likely, or possible).

When a download contains dives that look like ones you already have, the import review step lets you decide what to do with each:

| Action | What it does |
|--------|--------------|
| **Skip** | Leave the existing dive as-is and do not import the download. |
| **Import as new** | Add it as a separate dive anyway. |
| **Consolidate** | Attach the download to the matching dive as an additional computer's data (see below). |
| **Replace source** | Swap the matched dive's recorded data for this freshly downloaded version. |

### Matching dives to sites

If your downloaded dives carry GPS coordinates (see **Surface GPS** below), the import summary offers a **Match sites** step. It looks at the newly imported dives that have a position but no [dive site](dive-sites.md) yet, ranks your existing sites by distance, and proposes the nearest one &mdash; automatically assigning a clear match or suggesting candidates for you to confirm. Dives without GPS are not affected; you assign their sites by hand. You can also run this review any time from the **Dives** list menu under **Match sites**.

### Which diver the dives belong to

Downloaded dives are filed under the [diver profile](diver-profile.md) that is active when you download. If two people share one physical computer, each diver keeps their **own** record of that device and their own dives &mdash; switching the active profile keeps the two libraries cleanly separate.

### Linked computer

Each dive Submersion downloads stays linked to the computer that recorded it. On a dive's detail page, the dive-computer row is tappable and jumps straight to that computer's page, where you can see its stats and download again.

## Your computer's page

Tap any saved computer to open its detail page. It shows the model, serial number, connection type, and notes, plus statistics for **dives imported** and **last download**. From here you can:

- **Download dives** &mdash; pull new dives from this computer.
- **View dives** &mdash; jump to the [Dives](dive-logging.md) list filtered to this computer (by serial number).
- **Re-import all dives** &mdash; force a full re-download (shown once a download history exists).
- **Star it** as a favorite, **edit** its name and notes, or **delete** it.

## Using more than one computer

Many divers wear two computers for redundancy, or switch between a primary and a backup. Submersion handles this in two ways.

**Separate computers, separate records.** Pair as many computers as you like. Each keeps its own dive count, fingerprint, and download history.

**One dive, multiple computers.** When you download the *same* dive from a second computer, choose **Consolidate** at the duplicate review to attach it to the existing dive as an additional data source rather than creating a duplicate. A consolidated dive keeps every computer's full profile:

- The **dive profile** chart can overlay each computer's depth (and ceiling, temperature, and other traces) with per-computer toggles, so you can compare them side by side. The primary computer draws as a solid line; others as dashed lines.
- A **Computers** section on the dive detail lists each device with its own max depth, duration, temperature, and decompression settings.
- You can promote any computer to **primary** (its readings become the dive's headline figures) or **unlink** one to split it back out into its own dive.

If you did not consolidate at download time, you can still merge later: open a dive, choose **Merge with another dive**, and pick the matching dive recorded by the other computer.

> [!TIP]
> The **primary** computer supplies the numbers used in your [statistics](statistics.md) and summaries. Set whichever computer you trust most &mdash; usually your most accurate or most featureful one &mdash; as primary.

## Surface GPS (Shearwater Swift)

If you dive a **Shearwater Swift GPS** transmitter paired with a compatible Shearwater computer (Perdix, Petrel, Teric, and family), the transmitter records a GPS fix at **entry** (start of descent) and **exit** (on surfacing). Submersion reads both points during a direct download and stores them with the dive.

On the dive's detail page you then get:

- **Entry and exit pins** on the header map, with a line showing your surface drift between them.
- An optional **Surface GPS** section listing the entry and exit coordinates, the drift distance and bearing, and an **Open in Maps** button.

These coordinates are read straight from the dive computer's log and are read-only. They are recorded **per dive** &mdash; they do not silently create or move dive sites &mdash; but, as noted above, they are exactly what the post-download **Match sites** step uses to suggest a site for each dive.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| **The computer never appears when scanning** | Put it back into transfer/Bluetooth mode (it often times out), make sure Bluetooth is on, and keep the two devices close together. On Android, grant the Bluetooth/Nearby Devices permission when prompted. |
| **"Device not found. Make sure your computer is nearby and in transfer mode."** | The computer dropped out of pairing mode or moved out of range. Re-enable its transfer mode and scan again. |
| **The connection fails partway through** | Check the computer's battery, keep it within range for the whole transfer, and try again &mdash; incremental download means a retry only re-fetches what is missing. |
| **A PIN dialog keeps reappearing** | You may have mistyped the code. Each retry shows a fresh code on the computer; enter the current one. |
| **No dives downloaded** | If the computer is already up to date you will see the "no new dives" message &mdash; that is expected. To pull older dives again, use **Re-import all dives**. |
| **USB tab is empty / missing** | USB download is desktop-only (macOS, Windows, Linux). On a phone or tablet, use Bluetooth instead. |

## See also

- [Dive logging](dive-logging.md) &mdash; what happens to dives once they are imported.
- [Dive profiles](dive-profiles.md) &mdash; reading and overlaying the depth and decompression data you downloaded.
- [Dive sites](dive-sites.md) &mdash; how the post-download site matching works.
- [Import and export](import-export.md) &mdash; bringing in dives from files instead of a computer.
