# Encrypted Sync

Submersion's [Multi-Device Sync](multi-device-sync.md) uses cloud storage *you*
control &mdash; iCloud, or an S3-compatible bucket. By default your storage
provider encrypts your files at rest, but the provider itself can still read
your dive log: your sites and their GPS coordinates, buddy names, certification
details, and personal notes.

**End-to-end encryption** closes that gap. Turn it on and Submersion encrypts
every sync file &mdash; and every cloud backup &mdash; on your device *before*
it is uploaded, using a key derived from a passphrase only you know. Your
storage provider then sees nothing but opaque blobs. It is entirely optional and
off by default.

> [!TIP]
> <strong>You still own your storage &mdash; now you also hold the only key.</strong>
> There is still no Submersion server and no Submersion account. Encryption adds a
> passphrase that never leaves your devices, so not even your storage provider can
> read your logbook.

## What Encryption Protects (and What It Doesn't)

With encryption on, everything Submersion writes to your cloud storage &mdash;
sync changesets, the base snapshot, and cloud backups &mdash; is unreadable
without your passphrase.

- **Protected:** the full contents of your dive log and cloud backups. Your
  storage provider, or anyone who obtains your storage credentials, sees only
  ciphertext.
- **Not hidden:** file names, file sizes, timestamps, and how many devices you
  sync. Encryption protects the *contents* of your files, not the fact that they
  exist. If that metadata matters to you, keep your bucket private and your
  access token tightly scoped as well.
- **Your devices are unaffected.** The dive log stored on each device is never
  encrypted by this feature &mdash; only what leaves the device for the cloud.
  You never enter a passphrase to open the app or read your own dives.

## Turning On Encryption

Encryption is set up on **one** device and then adopted by the others.

1. Configure sync first. Encryption lives under **Settings &rarr; Cloud Sync**,
   in the **End-to-end encryption** section, and needs a storage backend already
   selected. Do this on the device that holds your library.
2. Tap **Enable encryption**.
3. Choose a **passphrase** (at least 8 characters) and confirm it. Pick something
   strong &mdash; it is the lock on your entire cloud library.
4. Submersion shows you a **recovery code**: eight words. Write it down and keep
   it somewhere safe, then tick **I have saved my recovery code** to continue.
   (More on the recovery code below.)
5. Leave **Delete existing unencrypted cloud backups** ticked (the default) so
   the plaintext copies already in your cloud are cleaned up.
6. Finish. Submersion re-uploads your whole library in encrypted form and every
   sync from now on is encrypted.

> [!WARNING]
> <strong>Every device must be updated first.</strong> Turning on encryption
> republishes your cloud library in a form older app versions cannot read. Update
> Submersion on all of your devices to the latest version before &mdash; or
> promptly after &mdash; enabling it. A device on an older version will simply stop
> syncing (with an error) rather than lose or damage anything, until you update it.

## Your Passphrase and Recovery Code

Encryption is protected by **two** secrets, and either one unlocks your library:

| Secret | What it is | Where it comes from |
|--------|-----------|---------------------|
| **Passphrase** | The phrase you chose when enabling encryption | You pick it |
| **Recovery code** | Eight words, shown once at setup | Generated for you |

The recovery code is your safety net for a forgotten passphrase. Keep it
somewhere separate from your devices &mdash; a password manager, or written down
and stored safely. When you type it, spacing, capitalization, and hyphens don't
matter.

> [!WARNING]
> <strong>If you lose both the passphrase and the recovery code, the data in your
> cloud storage cannot be recovered</strong> &mdash; there is no reset link and no
> Submersion account to recover through. The data on your devices is never at risk,
> though: see <strong>Recovering from a Lost Passphrase</strong> below.

## Adding Another Device

When a device that already has your (encrypted) library on the cloud tries to
sync, it needs the passphrase before it can read anything:

1. Install and update Submersion on the new device and connect it to the **same
   storage backend** as your others.
2. Run a sync. Because the library is encrypted and this device has no key yet,
   sync pauses and the Cloud Sync page shows an **Enter passphrase** banner.
3. Tap it and enter your passphrase (or your recovery code). Submersion unlocks
   the library, downloads it, and syncs normally from then on.

You enter the passphrase **once per device**. Submersion stores the unlocked key
in that device's secure keychain, so you are not asked again on that device.

## Managing Encryption

Once encryption is on, the **End-to-end encryption** section of
**Settings &rarr; Cloud Sync** offers:

| Action | What it does |
|--------|--------------|
| **Change passphrase** | Set a new passphrase. Takes effect immediately and does not require re-uploading your library. Your recovery code keeps working. |
| **Generate new recovery code** | Replace your recovery code with a fresh one. The old code stops working the moment you do this. Use it if you think your recovery code was exposed, or simply misplaced it. |
| **Turn off encryption** | Go back to unencrypted sync (see below). |

> [!TIP]
> <strong>There is no "show my recovery code."</strong> Submersion never stores the
> code itself, only enough to check it &mdash; so it genuinely cannot show it to
> you later. If you've lost it, use <strong>Generate new recovery code</strong> to
> make a fresh one you can save.

## Encrypted Cloud Backups

Encryption also covers your [cloud backups](backup-and-restore.md). While it is on,
every backup uploaded to your cloud storage is encrypted with the same
passphrase, and each encrypted backup is **self-contained**: you can restore it
on a brand-new device by entering the passphrase (or recovery code), even before
sync is configured there. Restoring works the same as any other backup &mdash;
Submersion just asks for the passphrase if the backup it's opening is encrypted
and the device doesn't already hold the key.

**Backups saved to a local folder, a connected drive, or the share sheet stay
unencrypted**, on purpose: a backup is your safety net, and it should never be
locked behind a passphrase you might forget. If you want those protected too,
encrypt the destination yourself (for example, an encrypted disk image or an
archive with its own password).

## Turning Off Encryption

**Turn off encryption** in the same section returns you to ordinary,
unencrypted sync. Submersion re-uploads your library in plaintext and your other
devices re-download it on their next sync &mdash; the mirror image of enabling
it. Backups you already made while encryption was on remain encrypted and stay
restorable with the passphrase you used at the time.

## Recovering from a Lost Passphrase

Losing your passphrase (and recovery code) does **not** mean losing your dives.
Your local library is never encrypted, so any device that already has your data
still has all of it in the clear. To get back to a working, synced state:

1. On a device that still has your dive log, **turn off encryption** (if it is
   still unlocked there), or **enable encryption** again with a **new**
   passphrase. Either one republishes the library from that device.
2. Your other devices adopt the new library on their next sync &mdash; entering
   the new passphrase if you kept encryption on.

The only thing you lose is the old encrypted copy in the cloud, which was
unreadable anyway. Your dives are safe.

## How It Works (Briefly)

For the technically curious: enabling encryption generates a random key for your
library and wraps it with a key derived from your passphrase (and separately
from your recovery code) using a slow, memory-hard key-derivation function. That
wrapped key is stored in a small keyslot file in your sync folder; the passphrase
and recovery code themselves are never stored anywhere. Every other file is
sealed with AES-256-GCM, so tampering is detected as well as prevented. Changing
your passphrase re-wraps the key without re-encrypting your whole library, which
is why it's instant.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| **A device shows an "Enter passphrase" banner and won't sync** | Expected on a device that hasn't been unlocked yet. Tap the banner and enter your passphrase or recovery code. |
| **"Incorrect passphrase or recovery code"** | Re-check for typos. The recovery code ignores case, spaces, and hyphens, so those aren't the problem; a wrong or misremembered word is. |
| **An older device stopped syncing after I enabled encryption** | Update Submersion on that device to the latest version, then unlock it with your passphrase. |
| **I forgot my passphrase and my recovery code** | See **Recovering from a Lost Passphrase** above &mdash; your local dives are safe; re-publish from a device that still has them. |
| **The Troubleshoot Sync screen shows "Locked"** | Same as the banner: the library is encrypted and this device needs the passphrase. Tap the row to unlock. |
