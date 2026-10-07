# Encrypted Sync

Submersion's [Multi-Device Sync](multi-device-sync.md) uses cloud storage you
control: iCloud, Google Drive, Dropbox, or an S3-compatible bucket. Your storage
provider normally encrypts your files at rest, but the provider itself can still
read your dive log: your sites and their GPS coordinates, buddy names,
certification details, and personal notes.

**End-to-end encryption** closes that gap. Turn it on and Submersion encrypts
every sync file, and every cloud backup, on your device before it is uploaded,
with a key derived from a passphrase only you know. Your storage provider then
sees nothing but unreadable data. It is optional and off by default.

> [!TIP]
> **You still own your storage, and now you also hold the only key.** There is
> still no Submersion server and no Submersion account. Encryption adds a
> passphrase that never leaves your devices, so not even your storage provider
> can read your logbook.

## What Encryption Protects (and What It Doesn't)

With encryption on, everything Submersion writes to your cloud storage (sync
changes, the library snapshot, and cloud backups) is unreadable without your
passphrase.

- **Protected:** the full contents of your dive log and cloud backups. Your
  storage provider, or anyone who obtains your storage credentials, sees only
  ciphertext.
- **Not hidden:** file names, file sizes, timestamps, and how many devices you
  sync. Encryption protects what is in your files, not the fact that they exist.
  If that matters to you, keep your bucket private and your access keys tightly
  scoped as well.
- **Your devices are unaffected.** This feature does not encrypt the dive log
  stored on each device, only what leaves it for the cloud. You never enter a
  passphrase to open the app or read your own dives. (To encrypt the log on the
  device itself, use **Encrypt database** in **Settings > App Security**; see
  [Settings](settings.md#app-security).)

## Turning On Encryption

Encryption is set up on one device and then adopted by the others.

1. Set up sync first. Encryption is in
   **Settings > Data > Database Cloud Sync**, under **End-to-end encryption**, and needs a cloud provider already
   chosen ("Select a cloud provider first" until then). Do this on the device
   that holds your library.
2. Tap **Enable encryption**.
3. Enter a **Passphrase** of at least 8 characters and confirm it. Pick
   something strong: it is the lock on your entire cloud library.
4. Leave **Delete existing unencrypted cloud backups** ticked (the default) so
   the unencrypted copies already in your cloud are cleaned up, and tap
   **Continue**.
5. Submersion shows your **Recovery code**: eight words. Write it down and keep
   it somewhere safe, tick **I have saved my recovery code**, and tap **Done**.
   (More on the recovery code below.)
6. Submersion re-uploads your whole library in encrypted form, and every sync
   from now on is encrypted.

> [!WARNING]
> **Every device must be updated first.** Turning on encryption republishes your
> cloud library in a form older app versions cannot read, and your other devices
> re-download it. Update Submersion on all of your devices to the latest version
> before, or promptly after, enabling it. A device on an older version stops
> syncing (with an error) rather than lose or damage anything, until you update
> it.

## Your Passphrase and Recovery Code

Encryption is protected by two secrets, and either one unlocks your library:

| Secret | What it is | Where it comes from |
|--------|-----------|---------------------|
| **Passphrase** | The phrase you chose when enabling encryption | You pick it |
| **Recovery code** | Eight words, shown once at setup | Generated for you |

The recovery code is your safety net for a forgotten passphrase. Keep it apart
from your devices, in a password manager or written down and stored safely. When
you type it, capitalisation doesn't matter, and you can separate the words with spaces or hyphens.

> [!WARNING]
> **If you lose both the passphrase and the recovery code, the data in your cloud storage cannot be recovered.** There is no reset link and no Submersion account
> to recover through. The data on your devices is never at risk, though: see
> [Recovering from a Lost Passphrase](#recovering-from-a-lost-passphrase).

## Adding Another Device

A device joining an encrypted library needs the passphrase before it can read
anything:

1. Install the latest Submersion on the new device and connect it to the same
   cloud provider as your others. (In the first-run setup, choose to bring in
   your existing data and connect cloud sync; the setup says "This library is
   encrypted" and asks for the passphrase there.)
2. Otherwise, run a sync. Sync pauses because this device has no key yet, and
   the Cloud Sync page shows that a passphrase is needed, with an
   **Enter passphrase** button.
3. Enter your passphrase or your recovery code in
   **Enter your encryption passphrase**. Submersion unlocks the library, downloads it, and syncs
   normally from then on.

You enter the passphrase once per device. Submersion keeps the unlocked key in
that device's secure keychain, so you are not asked again there.

## Managing Encryption

Once encryption is on, **End-to-end encryption** offers:

| Action | What it does |
|--------|--------------|
| **Change passphrase** | Set a new passphrase. It takes effect immediately without re-uploading your library, and your recovery code keeps working. |
| **Generate new recovery code** | Replace your recovery code with a new one. The old code stops working immediately. Use it if your recovery code may have been exposed, or you have lost it. |
| **Turn off encryption** | Go back to unencrypted sync (see below). |

> [!TIP]
> **There is no "show my recovery code".** Submersion never stores the code
> itself, only enough to check it, so it cannot show it to you later. If you have
> lost it, use **Generate new recovery code** to make one you can save.

## Encrypted Cloud Backups

Encryption also covers your [cloud backups](backup-and-restore.md). While it is
on, every backup uploaded to your cloud storage from an unlocked device is
encrypted with the same passphrase, and each one is self-contained: you can
restore it on a brand-new device by entering the passphrase or recovery code,
even before sync is set up there.

> [!WARNING]
> A device that has not been unlocked yet (one still waiting for the
> passphrase) uploads its cloud backups **unencrypted**. Enter the passphrase on
> each device before relying on the cloud backups it makes, or turn on
> **Encrypt backups** there, which encrypts them with its own password.

Backups saved to a local folder or shared from the device are not covered by
this passphrase. To protect those too, turn on **Encrypt backups** in
**Backup & Restore**, which uses a password of its own; see
[Backup encryption](backup-and-restore.md#backup-encryption).

## Turning Off Encryption

**Turn off encryption** returns you to ordinary, unencrypted sync. Submersion
re-uploads your library unencrypted and your other devices re-download it on
their next sync, the mirror image of enabling it. Backups made while encryption
was on stay encrypted, and restorable with the passphrase you used at the time.

## Recovering from a Lost Passphrase

Losing your passphrase and recovery code does not mean losing your dives. This
feature never encrypts the library on your devices, so any device that already
has your data still has all of it. To get back to a working, synced state:

1. On a device that still has your dive log, **turn off encryption** (if it is
   still unlocked there), or **enable encryption** again with a new passphrase.
   Either one republishes the library from that device.
2. Your other devices adopt the new library on their next sync, entering the new
   passphrase if you kept encryption on.

The only thing you lose is the old encrypted copy in the cloud, which was
unreadable anyway.

## How It Works (Briefly)

For the technically curious: enabling encryption generates a random key for your
library and wraps it with a key derived from your passphrase (and separately from
your recovery code) using Argon2id, a slow, memory-hard key-derivation function.
The wrapped key is stored in a small keyslot file in your sync folder; the
passphrase and recovery code themselves are never stored anywhere. Every other
file is sealed with AES-256-GCM, so tampering is detected as well as prevented.
Changing your passphrase re-wraps the key without re-encrypting your whole
library, which is why it is instant.

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| **A device says a passphrase is needed and won't sync** | Expected on a device that has not been unlocked yet. Tap **Enter passphrase** and enter your passphrase or recovery code. |
| **"Incorrect passphrase or recovery code"** | Check for typos. The recovery code ignores case and accepts spaces or hyphens between the words; check that every word is there and spelled right. |
| **An older device stopped syncing after I enabled encryption** | Update Submersion on that device to the latest version, then unlock it with your passphrase. |
| **I forgot my passphrase and my recovery code** | See [Recovering from a Lost Passphrase](#recovering-from-a-lost-passphrase): your local dives are safe; republish from a device that still has them. |
| **Troubleshoot Sync shows "Enter the passphrase to sync on this device"** | Same as above: the library is encrypted and this device needs the passphrase. Tap the **End-to-end encryption** row to unlock. |
