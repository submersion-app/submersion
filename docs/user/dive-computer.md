# Dive computers

Download your dives straight from a dive computer over Bluetooth or USB. Submersion reads the full profile (depth, temperature, tank pressure, gas mixes, decompression data, and more) and turns each recorded dive into a log entry.

> [!NOTE]
> **Where to find it:** Tap the **+** button on the **Dives** list and choose **Import from Computer**, or open **Transfer** in the main navigation. Transfer lists your **Known Computers** and offers **Connect New Computer** and, on iOS, **Import from Apple Watch**.

<!-- screenshot: images/dive-computer/discover.png: device discovery -->

## Supported computers and connections

Submersion talks to dive computers through **libdivecomputer**, the same open-source engine behind Subsurface and other dive-log tools, which supports 350+ models across the major brands: **Shearwater, Suunto, Mares, Scubapro, Oceanic, Aqualung, Cressi**, and many more. How a model can connect depends on the model and on your platform:

| Platform | Bluetooth LE | USB |
|----------|--------------|-----|
| **iOS** | Yes | No |
| **Android** | Yes | USB serial cables |
| **macOS, Windows, Linux** | Yes | USB serial cables and USB HID |

Bluetooth Classic and infrared are not supported.

The [support matrix](https://submersion.app/computers/) lists every model, the connections each platform can use for it, and what divers have reported: verified, issues, not working, or untested. Check your model there before buying a cable, and add your own result to fill a gap.

When you scan, Submersion shows a **Bluetooth** tab and a **USB Cable** tab. The Bluetooth tab discovers nearby devices live; the USB Cable tab lists supported models grouped by manufacturer so you can pick yours and connect the cable.

> [!TIP]
> Each discovered Bluetooth device is tagged. A **Supported** badge means the model is in libdivecomputer's library and should download automatically; a **Known** badge means you have already paired and downloaded from it before.

### Garmin watches

Garmin watches are not downloaded over Bluetooth or USB pairing. Their dives come in through one of these instead:

- **FIT files:** **Transfer** > **File Import**, then choose `.fit` files exported from Garmin Connect or copied from the watch.
- **Cable (desktop):** with the watch plugged in, **Transfer** > **File Import** shows **Import from Garmin Device**, which reads the watch's `GARMIN/Activity` folder.
- **Garmin Connect:** **Transfer** > **Cloud** > **Garmin** signs in to your account and imports dives directly.

A dive that comes with its FIT file is filed under the model that recorded it:

| Series | Models |
|--------|--------|
| **Descent** | Mk1, Mk2 / Mk2i, Mk2s, Mk3, Mk3i, X50i, G1, G2 |
| **Fenix** | Fenix 7, 7S, 7X, 7 Pro Solar, 7S Pro Solar, 7X Pro Solar, Fenix 8, 8 Solar, 8 Pro |
| **Epix** | Epix (Gen 2), Epix Pro (Gen 2) |
| **Enduro** | Enduro 2, Enduro 3 |
| **Tactix** | Tactix 7, Tactix 8 |

Other Garmin watches with a dive mode also import; they are labelled plainly "Garmin" until their model is added. A Garmin Connect dive with no FIT file (one entered by hand, for example) names no watch, so it is filed under a single "Garmin Connect" computer instead.

## Connecting a computer for the first time

1. Put your dive computer into its transfer or Bluetooth mode. Every brand does this differently, so check your computer's manual; the app cannot wake the device for you.
2. Start the connect flow: **Dives > + > Import from Computer**, or **Transfer > Connect New Computer**.
3. **Scan.** On the **Bluetooth** tab, wait for your computer to appear, then tap it. (For a wired computer, switch to the **USB Cable** tab, pick the model, and connect the cable.)
4. **Confirm.** Give the computer a name you will recognise, for example "My Perdix". A **Recognized Device** badge confirms Submersion knows how to talk to it. Tap **Connect & Download**.
5. **Download.** Submersion connects and pulls in your dives, showing progress as it goes.

After the first successful download, the computer is saved to your list so future downloads take a single tap.

### Entering a BLE PIN code

Some Bluetooth computers, notably **Aqualung and Apeks models built on the Pelagic chipset** (i300R, i330R, i470TC, i770R, Apeks DSX, and similar), require a one-time PIN to pair. When one is needed, the computer shows a code on its own screen and Submersion shows a **PIN Code Required** dialog. Type the code shown on the computer and tap **Submit**.

> [!TIP]
> You normally only enter the PIN once per device. Submersion securely remembers the access code it derives from your PIN, so later downloads connect without asking again. If the computer is factory-reset, it will simply ask for a new PIN.

## Downloading dives

Once a computer is saved, download from it by tapping it in your list (or the **download** icon next to it) and confirming. The download screen shows a progress ring, the current status, and each dive as it arrives.

<!-- screenshot: images/dive-computer/download-progress.png: download in progress -->

### New dives only vs. a full re-download

By default Submersion downloads **only the dives added since your last download**. It does this with libdivecomputer's fingerprint mechanism: after each successful import it remembers the newest dive, and on the next download the computer stops sending as soon as it reaches that point. This keeps downloads fast even on a computer that stores hundreds of dives.

- The **first** download from a computer has no previous point to stop at. If your logbook already has dives, Submersion asks how to start (**First download from this computer**): **Download all dives**, **Download new dives**, or **Only download dives after** a date you choose, so you can skip dives you logged some other way.
- If there is genuinely nothing new, the download tells you so.
- To pull every dive again from scratch (for example after a problem, or to recover dives you deleted in the app), open the computer's detail page and choose **Re-import all dives**. This option appears only once the computer has a saved download history.

### Keeping the computer's clock right

Turn on **Sync dive computer clocks** on the **Transfer** page and Submersion sets each computer's clock to this device's time after every download, on models that allow it, then reports **Clock synced** (or that clock sync is not supported by this model). It is off by default and applies to this device only. Each computer's page has a **Clock sync** card to override it for that computer: **Always**, **App setting**, or **Never**.

> [!WARNING]
> A full re-download of a computer with a large dive history can take several minutes. Keep the computer awake and within range for the whole transfer.

### Staying on the download screen

A download holds an open Bluetooth connection, so leaving the screen mid-transfer would silently abandon it. If you press back, switch tabs, or close the screen while a download is running, Submersion asks first:

> **Download in Progress**: leaving will cancel the current download from your dive computer.

Choose **Stay** to keep downloading, or **Leave** to cancel and navigate away. You can also stop a download yourself at any time with the **Cancel** button on the progress screen.

## After a download

### Duplicate detection

Submersion checks every downloaded dive against the dives already in your log so the same dive does not appear twice. Matching uses the computer's own dive fingerprint plus a comparison of start time, depth, and duration, with a tolerance for small clock drift between devices. Each match is rated by confidence (exact, likely, or possible).

When a download contains dives that look like ones you already have, the import review step lets you decide what to do with each:

| Action | What it does |
|--------|--------------|
| **Skip** | Leave the existing dive as-is and do not import the download. |
| **Import as New** | Add it as a separate dive anyway. |
| **Consolidate** | Attach the download to the matching dive as an additional computer's data (see below). When the match is high-confidence, **Consolidate** is pre-selected. |
| **Replace Source** | Swap the matched dive's recorded data for this freshly downloaded version. |

Re-downloading a dive from a computer that is already one of the dive's sources is recognised by fingerprint and defaults to **Skip**.

### Matching dives to sites

If your downloaded dives carry GPS coordinates (see **Surface GPS** below), the import summary offers a **Match sites** step. It looks at the newly imported dives that have a position but no [dive site](dive-sites.md) yet, ranks your existing sites by distance, and proposes the nearest one, assigning a clear match automatically or suggesting candidates for you to confirm. Dives without GPS are not affected; you assign their sites by hand. You can also run this review any time from the **Dives** list's overflow menu with **Match Dives to Sites**.

### Which diver the dives belong to

Downloaded dives are filed under the [diver profile](diver-profile.md) that is active when you download. If two people share one physical computer, each diver keeps their **own** record of that device and their own dives; switching the active profile keeps the two libraries cleanly separate.

### Linked computer

Each dive Submersion downloads stays linked to the computer that recorded it. On a dive's detail page, the dive-computer row is tappable and jumps straight to that computer's page, where you can see its stats and download again.

## Your computer's page

Tap any saved computer to open its detail page. It shows the model, serial number, connection type, and notes, plus **Statistics** for the dives imported and the last download. From here you can:

- **Download Dives**: pull new dives from this computer.
- **View Dives from This Computer**: open the [Dives](dive-logging.md) list filtered to this computer.
- **Re-import all dives**: force a full re-download (shown once a download history exists).
- **Re-parse all dives**: rebuild the dives from the raw data Submersion kept from each download, without connecting to the computer. Useful after an update that reads more from your model.
- **Merge with another computer**: when the same physical computer ended up as two entries (for example, after a reinstall), fold one into the other. A banner offers **Merge** when two entries share a serial number.
- Mark it as a favorite with the star, **Edit** its name and notes, or **Delete** it.

## Using more than one computer

Many divers wear two computers for redundancy, or switch between a primary and a backup. Submersion handles this in two ways.

**Separate computers, separate records.** Pair as many computers as you like. Each keeps its own dive count, fingerprint, and download history.

**One dive, multiple computers.** When you download the *same* dive from a second computer, choose **Consolidate** at the duplicate review to attach it to the existing dive as an additional data source rather than creating a duplicate. A consolidated dive keeps everything each computer recorded: profiles, tanks and transmitter pressure curves, events, and per-computer statistics.

- The **dive profile** chart can overlay each computer's depth (and ceiling, temperature, and other traces) with per-computer toggles in its **SOURCES** bar. The primary computer draws as a solid line; others as dashed lines.
- The dive's **Data Sources** section compares the computers side by side.
- You can promote any computer with **Set as primary** (its readings become the dive's headline figures), or **Split into separate dive** to move one back out into its own dive. See [Dive Profiles](dive-profiles.md#multiple-profiles-per-dive).

If the dives were already imported as separate entries, select them in the dive list and choose **Combine**. **Combine dives** offers two ways to bring them together:

- **Join into one dive**: for back-to-back records of one dive (for example, a computer that split a dive at a short surface interval).
- **Merge as another computer**: for the same dive recorded by two computers. When their clocks disagree, Submersion lines the records up by their depth profiles (**Best fit**) or by their starts (**Align starts**), shows the result before anything is saved, and suggests this mode when two computers' profiles match.

**Separate combined dives** on the dive undoes a combine.

> [!TIP]
> The **primary** computer supplies the numbers used in your [statistics](statistics.md) and summaries. Set whichever computer you trust most (usually your most accurate or most featureful one) as primary.

## Surface GPS (Shearwater Swift)

If you dive a **Shearwater Swift GPS** transmitter paired with a compatible Shearwater computer (Perdix, Petrel, Teric, and family), the transmitter records a GPS fix at **entry** (start of descent) and **exit** (on surfacing). Submersion reads both points during a direct download and stores them with the dive.

On the dive's detail page you then get:

- **Entry and exit pins** on the header map, with a line showing your surface drift between them.
- An optional **Surface GPS** section listing the entry and exit coordinates, the drift distance and bearing, with a full-screen map and coordinates you can copy.

These coordinates are read straight from the dive computer's log and are read-only. They are recorded **per dive** and never create or move dive sites on their own, but, as noted above, they are exactly what the post-download **Match sites** step uses to suggest a site for each dive.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| **The computer never appears when scanning** | Put it back into transfer or Bluetooth mode (it often times out), make sure Bluetooth is on, and keep the two devices close together. On Android, grant the Bluetooth and Nearby Devices permissions when prompted (older Android versions ask for Location for Bluetooth scanning). |
| **"Computer not found"** | The computer dropped out of pairing mode or moved out of range. Re-enable its transfer mode and scan again. |
| **The connection fails partway through** | Check the computer's battery, keep it within range for the whole transfer, and try again; incremental download means a retry only re-fetches what is missing. If the download stops partway, Submersion offers to import the dives it already received. |
| **A PIN dialog keeps reappearing** | You may have mistyped the code. Each retry shows a fresh code on the computer; enter the current one. |
| **No dives downloaded** | If the computer is already up to date, the download says there is nothing new; that is expected. To pull older dives again, use **Re-import all dives**. |
| **"No USB serial ports found"** | USB works on Android, macOS, Windows and Linux, not on iOS. Check the cable is connected and the computer powered on; on Android, allow Submersion to use the USB device when asked. |
| **Dive times are offset** | Check the computer's clock, or turn on **Sync dive computer clocks** (see [Keeping the computer's clock right](#keeping-the-computers-clock-right)). |

## See also

- [Dive logging](dive-logging.md): what happens to dives once they are imported.
- [Dive profiles](dive-profiles.md): reading and overlaying the depth and decompression data you downloaded.
- [Dive sites](dive-sites.md): how the post-download site matching works.
- [Import and export](import-export.md): bringing in dives from files instead of a computer.
