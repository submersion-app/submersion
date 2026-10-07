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

## Choosing a Cloud Provider

Open **Settings > Data > Database Cloud Sync** and choose under
**Cloud Provider**:

| Provider | Best for | Notes |
|----------|----------|-------|
| **iCloud** | All-Apple setups (iPhone, iPad, Mac) | Uses the iCloud account you are already signed in to. Apple devices only, and only in builds from the App Store. |
| **Google Drive** | Google accounts, on any mix of devices | Sign in with your Google account. Works on iOS, Android and macOS; on Windows and Linux only in builds that include Google sign-in. |
| **Dropbox** | Dropbox accounts | Sign in with your Dropbox account; files live in `Apps/Submersion`. |
| **S3-Compatible Storage** | Full control over where data lives | Any S3-compatible provider: Cloudflare R2, Amazon S3, Backblaze B2, MinIO, self-hosted. Every platform. You supply an endpoint, a bucket and access keys. |

A provider that is not available in your build says so. The
[Cloudflare R2 walkthrough](#example-cloudflare-r2-s3-compatible) at the end of
this page shows a complete setup that works on every platform.

## Enabling Sync

1. Open **Settings > Data > Database Cloud Sync**.
2. Choose a provider. For iCloud, Google Drive or Dropbox, sign in when asked.
   For S3-compatible storage, enter the endpoint, bucket and keys (see the
   [Cloudflare R2 example](#example-cloudflare-r2-s3-compatible)).
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
2. Otherwise, open **Settings > Data > Database Cloud Sync** and choose the
   **same provider** as your other devices: the same iCloud, Google or Dropbox
   account, or the same bucket and access keys.
3. Run **Sync Now**, and at **Combine Libraries?** choose **Merge and Sync**.

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
species and sightings, presets, dive computers, transmitters and cylinder fills,
GPS tracks, saved searches, near-miss reports, and your photo and video links.

Some things stay with each device, because the right answer differs from one
device to the next:

| Stays on each device | Why |
|----------------------|-----|
| Light or dark mode, and service reminder settings | Each device can look and notify its own way |
| Which diver profile is active | Two people can share a library on different devices |
| The navigation layout | Phones and computers have different room |
| A dive computer's Bluetooth address | Each device pairs on its own |
| The cloud provider and its sign-in, sync behaviour, and the encryption passphrase | Credentials never leave the device |
| Backup settings and location, update channel, debug mode, database location, App Security | Device housekeeping |
| Photo and video files | Only their links sync; the files themselves travel through [Media Sync](media-sync.md) |

## Sync Behavior

On the sync page:

| Option | What it does |
|--------|--------------|
| **Auto Sync** | Sync automatically after changes. |
| **Sync on Launch** | Check for updates when the app starts. |
| **Sync on Resume** | Check for updates when you return to the app. |
| **Sync Now** | Sync straight away. The status card shows when it last synced. |

## Switching or Removing a Provider

If you switch a device from one provider to another, Submersion asks first
(**Switch sync backend?**). Your data is not moved off the old provider; it stays
there until you delete it. After switching, this device's next sync combines its
data with whatever is already on the new provider, and Submersion offers to
clean up the old data once the switch is done.

- **Switching is per device.** Each device keeps using its current provider
  until you switch it.
- **Nothing is deleted without asking.** Your old data stays in the previous
  storage until you remove it.

**Sign Out**, under **Advanced**, disconnects this device. For S3-compatible
storage, **Remove Configuration** on the S3 settings forgets the endpoint and keys
on this device. Neither touches the data already in your storage.

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

## Troubleshooting

**Troubleshoot Sync**, under **Advanced** on the sync page, gathers the repair
tools: **Repair Sync** for a stuck sync, **Rebuild backend from this device**,
the devices that use this storage, and ways to remove this device's cloud files
or wipe all sync data from the storage.

**Replace cloud library**, in the sync page's **Danger Zone**, makes this
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

1. In Submersion, open **Settings > Data > Database Cloud Sync** and choose
   **S3-Compatible Storage**.
2. Fill in the four main fields:

| Field | What to enter |
|-------|---------------|
| **Endpoint URL** | The S3 endpoint from step 3, for example `https://<account-id>.r2.cloudflarestorage.com` |
| **Bucket** | The bucket name from step 2, for example `my-dive-log` |
| **Access Key ID** | From step 3 |
| **Secret Access Key** | From step 3 (tap the eye icon to show and check it) |

3. Leave the **Advanced** section alone. Submersion fills in the right
   **Region** (`auto`) for R2 and picks the addressing mode (
   **Use path-style addressing**) automatically, and the default **Key prefix**
   (`submersion-sync/`) keeps Submersion's files together in the bucket.
4. Tap **Test Connection**. Submersion writes a tiny test file to the bucket,
   reads it back, and deletes it to confirm the keys work. You should see
   **Connection successful**.
5. Tap **Save**.
6. Run **Sync Now** to seed your library into the bucket.

### 5. Repeat on Your Other Devices

Enter the same four values on each additional device, tap **Test Connection**,
then **Save**. On the first sync, choose **Merge and Sync** at the
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
| **Test Connection fails with an access or signature error** | Check the Access Key ID and Secret Access Key for stray spaces. Confirm the token's permission is **Object Read & Write** and that it applies to this bucket. |
| **Test Connection reports a region problem** | Open **Advanced** and check **Region**; for R2 it should be `auto`. Run the test again. |
| **The endpoint is rejected as invalid** | The endpoint must be a full `https://` address with nothing after the host name: `https://<account-id>.r2.cloudflarestorage.com`, not a `/bucket` path. The bucket name goes in its own field. |
| **A dive appears twice after adding a device** | That dive was logged separately on both devices before they were merged. Delete the duplicate; the deletion syncs to the others. |
| **No dives appear on the new device** | Make sure you tapped **Merge and Sync** at the Combine Libraries prompt, and that every device uses the same bucket and keys. |
