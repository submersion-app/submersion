# Set Up This Device

**Set up this device** walks you through the four things that keep a logbook
safe and the same everywhere: where your data is kept, sync, backups and photo
copies. It takes a minute or two, every step can be left for later, and nothing
is turned on until you press **Next** on that step.

> [!TIP]
> **In the app this is the card at the top of Settings > Data** (and of
> Settings on a phone). It reads **Set up this phone** (or tablet, or computer),
> shows how many of the four steps are done, and **Continue** opens the next
> one.

## The card

The card lists the four steps with a mark beside each:

| Step | Done when |
|------|-----------|
| **Choose where your data is kept** | Sync, the backup copy or the photo copies name an account on this device |
| **Keep dives on every device** | Sync names an account and has finished a sync |
| **Back up automatically** | Automatic backups are on and a copy goes somewhere other than this device |
| **Share photo copies (optional)** | This device keeps photo copies in an account, or you chose **Skip** |

The card works out each mark from the features themselves, so it never claims a
step that the feature's own page does not show. Set something up from its own
page and the card catches up.

**Hide this card** puts it away. To bring it back, open **Settings > Data >
Advanced > Set up this device again**, which also appears once all four steps
are done. It opens the flow from the first step with every step shown.

The card also carries anything this device needs from you later: an account to
sign in to again, or photo copies another device keeps that this one has not
joined yet.

## Step 1: Where should Submersion keep your data?

Choose an account: iCloud, Google Drive, Dropbox, or your own server (WebDAV or
S3). Accounts already signed in on this device are listed first. If you add an
account here, you sign in as usual; for an account another device added, you
type only its key or password.

Choosing an account writes nothing yet. It is held for the next steps. If you
would rather start from a backup file, **I have a backup file instead** opens
Restore from a file.

## Step 2: Dives on every device

Sync is pointed at the account you chose, and the step reads what is there:

- **No library yet.** The dives on this device become the library all your
  devices share. **Turn on sync** uploads them.
- **A library is found.** The step names the device that changed it last and
  when. With no dives here, **Download library** simply brings it down. With
  dives here, choose:
  - **Combine them** (the default): the dives here join the library. A dive
    logged separately on both devices appears twice.
  - **Replace the dives here with the library**: a backup of the dives here is
    saved first, under Backups, then the library replaces them. You confirm by
    typing a word, and Submersion reloads when it is done.
- **The library is encrypted.** Type the passphrase or recovery code to unlock
  it.
- **The library was replaced on another device.** Adopt it here, with a backup
  of this device's dives saved first.

**Keep devices in step automatically** (on) turns on syncing a few seconds after
each change, at launch and when the app returns. Turn it off to sync only when
you choose **Sync Now**.

## Step 3: A backup that survives a lost device

Sync keeps devices in step; a backup is a copy from a moment in time that you
can go back to. Two switches, both on:

- **Back up automatically**, with your schedule and how many backups are kept.
  On a computer, scheduled backups run while Submersion is open.
- **Also keep a copy in {account}**. When that is the account sync uses, the
  copy follows sync. Any other account holds the copy itself.

With no account at all, the step explains that a copy off this device needs an
account or a backup folder, with a link to Backups. The schedule, the folder,
password protection and old backups stay on the Backups page.

## Step 4: Photos on every device

This step is optional; **Skip** settles it.

- **On your first device**, **Keep photo copies in {account}** starts off, with
  the number of photos and videos attached to your dives. Turn it on to choose
  **Upload new photos automatically** (on) and **Use cellular data** (off).
  Nothing is uploaded until you do.
- **On a later device**, where your library already keeps copies,
  **Use the photo copies in {account}** starts on. When those copies are in the
  account you chose in step 1, there is nothing to type. Otherwise the step
  signs in to their account first.

Your originals always stay where they are; see [Media Sync](media-sync.md).

## Done

The last screen says **This phone is set up**, with one line each for your
accounts, sync, backups and photos, in the same words the Settings > Data rows
use. It ends with how your other devices join: open Submersion, choose the same
account, and the same library appears. If some photos attached here are not
copied yet, **Upload everything already attached** queues them.

## Your other devices

On each other device, open **Set up this device** and choose the **same
account** in step 1. Step 2 finds your library and downloads it, or combines it
with any dives already there. For more on how devices share one library, see
[Multi-Device Sync](multi-device-sync.md).

## Each feature on its own

Every step is also its own page under Settings > Data. A row that is not set up
shows **Set up** under its status, which opens that step of this flow: Backups
opens step 3, Photos & videos step 4, and Sync between devices step 1, starting
from the account sync last used.

## See also

- [Settings](settings.md)
- [Backups](backup-and-restore.md)
- [Multi-Device Sync](multi-device-sync.md)
- [Media Sync](media-sync.md)
- [Encrypted Sync](encrypted-sync.md)
