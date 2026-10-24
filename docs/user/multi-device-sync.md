# Multi-Device Sync

Submersion can keep your dive log in step across every device you use (phone,
tablet and computer), so a dive you download on one shows up on all of them.

Sync is "bring your own storage." Your dive data lives in a cloud account you
control, and Submersion reads and writes a small set of sync files there. There
is no Submersion server in the middle and no Submersion account to create: you
own the storage, and you own the data.

> [!TIP]
> Set up the device that already has your dives first. It seeds the shared
> library, and every other device then merges into it.

## How Sync Works

Once a device is connected to a cloud provider, Submersion keeps it up to date
automatically:

- Every device reads the latest shared library from your storage and writes its
  own changes back to it.
- Syncs are incremental. The first sync uploads your library once; after that,
  each sync transfers only what changed, so even a large dive log stays quick to
  sync.
- New dives, edits and deletions made on one device reach the others on their
  next sync.
- When two devices change the same thing, the most recent change wins,
  automatically. The rare change Submersion cannot settle on its own (for
  example, a record edited on one device and deleted on another) appears under
  **Conflicts** on the sync page, with **Resolve Conflicts** to choose which
  version to keep, or **Keep Both**.
- The first device to connect seeds the library. When another device connects
  to a provider that already has data, Submersion asks whether to combine the
  two libraries before merging anything (see
  [Adding More Devices](#adding-more-devices)).
- Your connection details are stored in the device's secure keychain, never in
  the dive database, and never sent to Submersion.

## Choosing an Account

Sync runs through an **account**: the sign-in it uses. Open
**Settings > Data > Sync between devices**; the top row says which account sync
uses (**Using: ...**), or **Not set up**. **Set up** or **Change** opens the
account sheet, which lists the accounts you already have, then the kinds you
can add:

| Account | Best for | Notes |
|----------|----------|-------|
| **iCloud** | All-Apple setups (iPhone, iPad, Mac) | Uses the iCloud account you are already signed in to. Apple devices only, and only in builds from the App Store. |
| **Google Drive** | Google accounts, on any mix of devices | Sign in with your Google account. Works on iOS, Android and macOS; on Windows and Linux only in builds that include Google sign-in. |
| **Dropbox** | Dropbox accounts | Sign in with your Dropbox account; files live in `Apps/Submersion`. |
| **My own server** | Full control over where data lives | An S3-compatible bucket (Cloudflare R2, Amazon S3, Backblaze B2, MinIO, self-hosted) or a WebDAV server. Every platform. You supply the address and the keys or password. |
| **Git repository** | Divers who already keep things in Git | Any Git host over HTTPS: GitHub, GitLab, Gitea, Forgejo, Bitbucket, self-hosted. Every platform. You supply a repository address, a username and an access token. See [Git repositories](#git-repositories). |

A kind that cannot sign in on your device or build is not offered. Every
account you add also appears under **Settings > Data > Connected accounts**,
where you can sign in again, sign out on this device, or remove it. The
[Cloudflare R2 walkthrough](#example-cloudflare-r2-s3-compatible) at the end of
this page shows a complete setup that works on every platform.

## Enabling Sync

1. Open **Settings > Data > Sync between devices** and tap **Set up**.
2. Choose an account, or add one. For iCloud, Google Drive or Dropbox, sign in
   when asked. For **My own server**, enter the address, bucket and keys (see
   the [Cloudflare R2 example](#example-cloudflare-r2-s3-compatible)). For
   **Git repository**, enter the repository address, username, access token
   and branch (see [Git repositories](#git-repositories)).
3. Run the first sync with **Sync Now**.

### The "Combine Libraries?" Prompt

The first time a device syncs to a provider that already holds dives from
another device, Submersion stops and asks before merging. **Combine Libraries?**
says how much sync data it found, and that the first sync will combine it with
the dives on this device.

Choose **Merge and Sync** to bring the two libraries together. That is what you
want when adding a new device to an existing library.

> [!WARNING]
> **Watch for duplicates.** If you logged the same dive separately on two devices
> before connecting them, merging keeps both copies, and the dive appears twice.
> Merge a new device into the library before you start logging on it, not after.
> If this device's library should simply become everyone's, use
> **Replace cloud library** instead (see [Troubleshooting](#troubleshooting)).

## Adding More Devices

1. Install Submersion on the new device. In the first-run setup you can choose
   to bring in your existing data and connect cloud sync straight away.
2. Otherwise, open the **Set up this device** card on **Settings > Data** and
   choose the **same account** as your other devices: the same iCloud, Google
   or Dropbox account, or the same server. An account another device added is
   already listed; for your own server you only type the key or password.
3. The next step finds your library and names the device that changed it last.
   With no dives on the new device, **Download library** brings it down. With
   dives there, choose:
   - **Combine them**: the dives on the new device join the library.
   - **Replace the dives here with the library**: a backup of the dives on the
     new device is saved under Backups first, then the library replaces them
     and Submersion reloads. Restore that backup if you change your mind.

You can still connect from **Settings > Data > Sync between devices** with
**Change**, then **Sync Now** and, at **Combine Libraries?**, **Merge and
Sync**. See [Set Up This Device](set-up-this-device.md) for the whole flow.

From then on, all connected devices share one library. If your library is
encrypted, the new device asks for your passphrase; see
[Encrypted Sync](encrypted-sync.md).

### Duplicate diver profiles

If each device created its own diver profile before they were connected, you may
end up with two profiles of the same name. The sync page then shows
**Duplicate diver profiles**, with a **Merge** button for each name. Merging moves every
dive, certification, piece of gear and everything else from the duplicates onto
one profile (your default profile, or else the oldest). **Undo** in the
confirmation reverses the whole merge.

## What Syncs Between Devices

Your whole dive log syncs: divers and their settings, dives (with tanks, weights,
gear, buddies, tags, profiles and safety reviews), sites, trips, dive centers,
equipment and its service history, certifications and courses, dive plans,
species and sightings, presets, dive computers and the ways each one has been
downloaded or imported, transmitters and cylinder fills,
GPS tracks, saved searches, near-miss reports, and your photo and video links.

Some things stay with each device, because the right answer differs from one
device to the next:

| Stays on each device | Why |
|----------------------|-----|
| Light or dark mode, and service reminder settings | Each device can look and notify its own way |
| Which diver profile is active | Two people can share a library on different devices |
| The navigation layout | Phones and computers have different room |
| A dive computer's Bluetooth address or USB port, and which connection this device last downloaded it over | Each device pairs on its own |
| The cloud provider and its sign-in, sync behaviour, and the encryption passphrase | Credentials never leave the device |
| Backup settings and location, update channel, debug mode, database location, App Security | Device housekeeping |
| Photo and video files | Only their links sync; the files themselves travel through [Media Sync](media-sync.md) |

## Sync Behavior

On the sync page:

| Option | What it does |
|--------|--------------|
| **Keep devices in step automatically** | Sync automatically after changes. |
| **Also sync at launch** (under **Advanced**) | Check for updates when the app starts. Needs automatic sync on. |
| **Also sync when the app returns** (under **Advanced**) | Check for updates when you return to the app. Needs automatic sync on. |
| **Sync Now** | Sync straight away. The status card shows when it last synced. |

## Switching or Stopping Sync

**Change** on the account row switches this device to another account. If it
has synced before, the account sheet explains first what switching does. Your
data is not moved off the old account; it stays
there until you delete it. After switching, this device's next sync combines its
data with whatever is already on the new provider, and Submersion offers to
clean up the old data once the switch is done.

- **Switching is per device.** Each device keeps using its current account
  until you switch it.
- **Nothing is deleted without asking.** Your old data stays in the previous
  storage until you remove it.

**Stop syncing on this device**, under **Advanced**, turns sync off here and
keeps the account signed in. A backup copy that went to the same account as
sync keeps going there. To forget an account's keys on this device, use
**Sign out on this device** on the account in **Connected accounts**; **Remove
from all devices** takes it off the account list everywhere. None of these
touches the data already in your storage. Deleting the old account's data after
a switch asks first.

## Security and Privacy

- **Credentials stay on the device.** Endpoints, bucket names, access keys and
  sign-ins are stored in your platform's secure keychain, not in the dive
  database, and never sent to Submersion.
- **Your data lives in your storage.** Anyone with your storage credentials can
  read it, so keep them safe and scope them narrowly (see step 3 of the R2
  example).
- **Encrypted in transit.** Submersion talks to S3-compatible storage over HTTPS.
  If you enter a plain `http://` endpoint, the app warns you that credentials and
  dive data will travel unencrypted; only do this on a trusted local network.
- **Encrypted at rest.** Cloud providers encrypt stored files at rest. This keeps
  outsiders out, but the provider itself can still read them.
- **Optional end-to-end encryption.** If you want your storage provider unable to
  read your logbook at all, turn on end-to-end encryption: Submersion then
  encrypts every sync file and cloud backup on your device before upload, with a
  key only you hold. See [Encrypted Sync](encrypted-sync.md).

## Git Repositories

Submersion can sync through a repository on any Git host. It talks to the host
itself over HTTPS, so nothing else needs to be installed on your devices.

**What to enter:**

- **Repository address:** the HTTPS address you would clone from, for example
  `https://github.com/you/dive-log.git`. On GitHub, GitLab, Bitbucket, Gitea
  and Forgejo the repository's web address works too; on any other host, paste
  the clone address exactly as the host shows it.
- **Username and access token:** create a token on the host that can push to
  this one repository. The setup screen shows which kind to create for the host
  in your address:
  - **GitHub:** a fine-grained token for the repository, with *Contents: read
    and write*.
  - **GitLab:** a personal or project access token with `write_repository`.
    GitLab tokens expire within a year; paste a new one when sync says the
    token was rejected.
  - **Bitbucket:** an API token with repository read and write access. App
    passwords no longer work.
  - **Gitea and Forgejo:** an access token with `write:repository`.
- **Branch:** `submersion-sync` unless you choose another name.

**How the repository is used:**

- **Submersion keeps its branch to itself.** It writes only to a branch it
  created. It refuses a branch that already holds other content, so your
  `main` and other branches are never touched.
- **History is reset now and then.** Sync snapshots are large and Git keeps
  every old one, so once enough has been deleted Submersion replaces its
  branch's history with a single fresh commit. Your hosting service frees the
  space on its own schedule.
- **Backups go there too.** When cloud backup is on, backups are stored in the
  same repository under `Submersion Backups`.
- **A repository used only for Submersion works best.** In an empty repository,
  Submersion's branch becomes the default branch.

**Public repositories** are allowed only with
[Encrypted Sync](encrypted-sync.md) turned on, so your dive data is never
readable by others. If the repository is public, Submersion saves the settings
but does not sync until you turn encryption on, and it will not let you turn
encryption off while it can see the repository is public. Even if the host
does not answer in time and encryption is turned off, nothing unencrypted is
uploaded to a public repository: sync stops until encryption is back on or the
repository is private. Cloud backups to a public repository also need backup
encryption: an unencrypted backup is refused.

## Troubleshooting

**Troubleshoot**, under **Advanced** on the sync page, gathers the repair
tools: **Repair Sync** for a stuck sync, **Rebuild backend from this device**,
and ways to remove this device's cloud files or wipe all sync data from the
storage. **Devices using this library**, also under **Advanced**, lists the
devices that use this storage.

**Replace the library with this device's copy**, under **Advanced**, makes this
device's library the one every device uses; the other devices are asked to adopt
it before their next sync.

---

## Example: Cloudflare R2 (S3-Compatible)

[Cloudflare R2](https://developers.cloudflare.com/r2/) is a convenient
S3-compatible provider: it has a generous free monthly allowance, charges no
fees for downloads, and works on every platform Submersion supports. This
walkthrough sets it up end to end.

> [!TIP]
> **Terminology:** R2 has no separate "tenancy" to create: your Cloudflare
> account is the tenant. Your account's ID is part of the storage endpoint
> (`https://<account-id>.r2.cloudflarestorage.com`), which Cloudflare shows you
> when you create your keys, so you do not need to look it up separately.

### 1. Enable R2

1. Sign in at [dash.cloudflare.com](https://dash.cloudflare.com/) (create a free
   account if you do not have one).
2. In the sidebar, go to **Storage & databases > R2 > Overview**.
3. Complete the checkout flow to add an R2 subscription. R2 includes a free
   monthly allowance; you may be asked to put a payment method on file before the
   bucket tools unlock.

### 2. Create a Bucket

1. On the R2 page, select **Create bucket**.
2. Enter a **bucket name**: lowercase letters, numbers and hyphens, 3 to 63
   characters, not starting or ending with a hyphen. For example, `my-dive-log`.
3. Optionally choose a **Location** to keep data near you. For strict data
   residency, choose **Specify jurisdiction** (for example, **EU**) instead; this
   changes your endpoint (see [Jurisdiction endpoints](#jurisdiction-endpoints)).
4. Create the bucket and note its name; you will enter it in Submersion.

### 3. Create API Credentials (Access Keys)

1. From the R2 **Overview** page, open **API Tokens** (the
   **Manage R2 API Tokens** link in the account details area).
2. Select **Create Account API token**. An account token stays valid until you
   revoke it, which is what you want for a long-lived sync setup.
3. For **Permissions**, choose **Object Read & Write**: this lets Submersion read,
   write and list objects, but not manage your other buckets.
4. Apply the token to **specific buckets**, and select the bucket you created.
   Limiting a token to one bucket is good security practice.
5. Create the token. Cloudflare now shows you three values:
   - **Access Key ID**
   - **Secret Access Key**
   - **S3 endpoint** (`https://<account-id>.r2.cloudflarestorage.com`)

> [!WARNING]
> **Copy the Secret Access Key now.** Cloudflare shows it only once. Copy all three
> values somewhere safe before leaving the page; if you lose the secret, you will
> have to create a new token.

### 4. Configure Submersion (First Device)

1. In Submersion, open **Settings > Data > Sync between devices**, tap
   **Set up**, then **My own server**, and keep **S3-compatible** selected.
2. Fill in the four main fields:

| Field | What to enter |
|-------|---------------|
| **Endpoint URL** | The S3 endpoint from step 3, for example `https://<account-id>.r2.cloudflarestorage.com` |
| **Bucket** | The bucket name from step 2, for example `my-dive-log` |
| **Access Key ID** | From step 3 |
| **Secret Access Key** | From step 3 (tap the eye icon to show and check it) |

3. Leave the **Advanced** section alone. Submersion fills in the right
   **Region** (`auto`) for R2 and picks the addressing mode (
   **Use path-style addressing**) automatically, and keeps its sync files
   together in the bucket's `submersion-sync/` folder.
4. Tap **Check connection**. Submersion writes a tiny test file to the bucket,
   reads it back, and deletes it to confirm the keys work. You should see
   **Connection successful**.
5. Tap **Save**, then choose the new account for sync.
6. Run **Sync Now** to seed your library into the bucket.

### 5. Repeat on Your Other Devices

On each additional device, open **Set up** on the sync page and choose the
account, which is already listed; enter the access keys when asked. (On a
device that has never seen it, add **My own server** with the same four values.)
On the first sync, choose **Merge and Sync** at the
**Combine Libraries?** prompt. All of your devices now share one library through R2.

### Jurisdiction endpoints

If you created the bucket with a jurisdiction for data residency, use the
matching endpoint in the **Endpoint URL** field. Submersion recognises all of
them as R2 and sets the region for you.

| Jurisdiction | Endpoint |
|--------------|----------|
| Default | `https://<account-id>.r2.cloudflarestorage.com` |
| EU | `https://<account-id>.eu.r2.cloudflarestorage.com` |
| FedRAMP | `https://<account-id>.fedramp.r2.cloudflarestorage.com` |

### R2 Troubleshooting

| Problem | What to try |
|---------|-------------|
| **Check connection fails with an access or signature error** | Check the Access Key ID and Secret Access Key for stray spaces. Confirm the token's permission is **Object Read & Write** and that it applies to this bucket. |
| **Check connection reports a region problem** | Open **Advanced** and check **Region**; for R2 it should be `auto`. Run the test again. |
| **The endpoint is rejected as invalid** | The endpoint must be a full `https://` address with nothing after the host name: `https://<account-id>.r2.cloudflarestorage.com`, not a `/bucket` path. The bucket name goes in its own field. |
| **A dive appears twice after adding a device** | That dive was logged separately on both devices before they were merged. Delete the duplicate; the deletion syncs to the others. |
| **No dives appear on the new device** | Make sure you tapped **Merge and Sync** at the Combine Libraries prompt, and that every device uses the same bucket and keys. |
