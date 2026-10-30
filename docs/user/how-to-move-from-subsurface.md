# Moving from Subsurface to Submersion

When you finish this guide, your Subsurface logbook will be in Submersion: your dives with their full profiles, trips, sites, buddies, tanks and photos.

Submersion reads Subsurface's own XML logbook, so nothing has to be converted on the way.

## What comes across

| Comes across | Does not come across |
|---|---|
| Dives with their profiles, events and gas switches | Equipment other than your suit |
| Every dive computer's reading of a dive | Certifications |
| Trips, with their names and notes | Several divers in one logbook |
| Dive sites, with GPS, country and region | |
| Buddies and dive masters | |
| Tanks, with gases, roles and pressures | |
| Tags, ratings, visibility, current and notes | |
| Photos linked to your dives | |

## Before you start

You need:

- Subsurface, with your logbook open.
- Submersion on a computer, if you want your photos linked too. Dives import on any device.
- About 10 minutes.

## 1. Export your logbook from Subsurface

1. In Subsurface, choose **File > Export**.
2. Select **Subsurface XML**, choose to export all dives, and save the file somewhere you can find it.

If your logbook is a local `.ssrf` file, you can import that file directly instead.

## 2. Open it in Submersion

1. Open **Transfer** (on a phone it is under **More**), choose **File Import**, then tap the **File Import** card.
2. Tap **Select Files** and choose the file you exported. On a computer you can also drag the file onto the Submersion window; on a phone you can share it to Submersion from your Files app.
3. Submersion recognises the file as Subsurface XML. Tap **Next**.

![Confirm Source showing a detected Subsurface XML file](images/how-to/move-from-subsurface/01-confirm-source.png)

## 3. Link your photos

If your Subsurface dives have pictures, Submersion asks where they are. Click **Choose photo folder...** and pick the folder that holds them; Submersion links to them there and never copies them.

On a phone or tablet, tap **Skip photos**. Dives import as normal, and you can link photos later or run the import again on a computer.

![The Photos step with the referenced photo count and the match summary after choosing a folder](images/how-to/move-from-subsurface/02-photos.png)

## 4. Review and import

The review screen has a tab for each kind of record: **Dives**, **Sites**, **Buddies**, **Trips** and more. Everything new is ticked.

- Any dive that looks like one already in Submersion is listed under **Potential Duplicates** or **Possible Duplicates**. Choose **Skip**, **Import as New** or **Consolidate** for each before importing.
- Tap **Options** to keep Subsurface's dive numbers (**Retain source dive numbers**).

Tap **Import Selected**.

![The review step on the Dives tab with the Trips and Sites tabs and Import Selected](images/how-to/move-from-subsurface/03-review.png)

## Check it worked

When **Successfully Imported** appears, tap **View Dives**. Open a dive that used more than one dive computer: each computer's reading is kept, and the profile shows them together.

## If something goes wrong

**"Some dives have no dive site".** Those dives pointed at a site the file does not describe, so they came in without one. Set a site by editing the dive.

**The Photos step says some photos were not found.** They are not in the folder you chose. Before importing, click **Choose photo folder...** again and pick the folder that holds them.

**"Some photos skipped".** Those pictures had no file name in Subsurface, so they cannot be linked. Attach them to their dives by hand.

**Importing the same file again?** Dives you already imported show up as duplicates. Choose **Skip** for them, or use the button that skips them all at once.

**The file is not recognised.** Make sure you exported **Subsurface XML**, not CSV or UDDF. (Submersion reads UDDF too, but the Subsurface XML keeps more.)

## Next steps

- [Import & Export](import-export.md): every format Submersion reads, and how duplicates are handled.
- [Trips](trips.md): your imported trips.
- [Set Up Sync, Backups and Photos](how-to-sync-backups-photos.md): your logbook on all your devices.
