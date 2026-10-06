# Multi-Device Sync

Submersion can keep your dive log in sync across every device you use &mdash;
phone, tablet, and computer &mdash; so a dive you download on one shows up on all
of them.

Sync is **"bring your own storage."** Your dive data lives in a cloud account
*you* control, and Submersion reads and writes a small set of app-managed sync
files there. There is no Submersion server in the middle and no Submersion
account to create: you own the storage, and you own the data.

<div class="tip">
<strong>Tip:</strong> Set up the device that already has your dives <em>first</em>.
It seeds the shared library, and every other device then merges into it.
</div>

## How Sync Works

Once you connect a device to a storage backend, Submersion keeps it up to date
automatically:

- Every device reads the latest shared library from your storage and writes its
  own changes back to it.
- Syncs are **incremental**. The first sync uploads your library once; after
  that, each sync transfers only what actually changed &mdash; so even a large
  dive log stays fast to sync and does not need the app left open.
- New dives, edits, and deletions made on one device propagate to the others on
  the next sync.
- The **first** device to connect seeds the library. When another device
  connects to a backend that *already* has data, Submersion asks whether to
  **combine** the two libraries before merging anything (see **Adding More
  Devices** below).
- Your connection details are stored in the device's secure keychain &mdash;
  never in the dive database, and never sent to Submersion.

<div class="tip">
<strong>One library, many devices:</strong> Sync is built around a single shared
dive log that all of your devices read from and write to &mdash; not separate
logs that occasionally copy to each other.
</div>

## Choosing a Storage Backend

Open **Settings &rarr; Cloud Sync** and pick the backend that fits your devices:

| Backend | Best for | Notes |
|---------|----------|-------|
| **iCloud** | All-Apple setups (iPhone, iPad, Mac) | Simplest option &mdash; uses the iCloud account you're already signed into. Apple platforms only. |
| **S3-Compatible Storage** | Mixed platforms, or full control over where data lives | Works with any S3-compatible provider (Cloudflare R2, Amazon S3, Backblaze B2, MinIO, self-hosted). Available on every platform: iOS, Android, macOS, Windows, and Linux. You supply an endpoint, a bucket, and access keys. |

<div class="tip">
<strong>More backends are on the way.</strong> Additional storage providers are
planned for upcoming releases. If you sync across a mix of Apple and non-Apple
devices today, the S3-compatible backend is the one that reaches all of them
&mdash; the <strong>Cloudflare R2 walkthrough</strong> at the end of this page
shows a complete, free setup.
</div>

<div class="screenshot-placeholder">
  <strong>Screenshot 1: Cloud Sync backends</strong><br>
  <em>The Cloud Sync settings page listing the available backends.</em>
</div>

## Enabling Sync

The details you enter depend on the backend, but the flow is always the same:

1. Open **Settings &rarr; Cloud Sync**.
2. Select a backend and provide its connection details. For iCloud, select it and
   sign in if prompted. For S3-compatible storage, enter the endpoint, bucket, and
   keys (see the **Cloudflare R2 example** below).
3. Confirm the connection and tap **Save**.
4. Run the first sync with **Sync Now**.

### The "Combine Libraries?" Prompt

The first time a device syncs to a backend that *already contains* dives from
another device, Submersion pauses and asks before merging:

> **Combine Libraries?** &mdash; Existing sync data was found in the cloud. Your
> first sync will combine that data with the dives on this device, across every
> synced device.

Choose **Merge and Sync** to bring the two libraries together. This is exactly
what you want when adding a new device to an existing library.

<div class="warning">
<strong>Heads up on duplicates:</strong> If you logged the <em>same</em> dive
separately on two devices before connecting them, merging keeps both copies
&mdash; they will appear twice. Merge a new device into the library <em>before</em>
you start logging on it, not after.
</div>

<div class="screenshot-placeholder">
  <strong>Screenshot 2: Combine Libraries prompt</strong><br>
  <em>The first-sync confirmation dialog showing the dive and device counts that will be merged.</em>
</div>

## Adding More Devices

To put your log on another device:

1. Install Submersion on the new device.
2. Open **Settings &rarr; Cloud Sync** and choose the **same backend** as your
   other devices &mdash; the same iCloud account, or the **same bucket and access
   keys** for S3-compatible storage.
3. Run **Sync Now**. Because the backend already holds your library, you will see
   the **Combine Libraries?** prompt &mdash; choose **Merge and Sync**.

From then on, all connected devices share one library.

## Sync Options

Under **Settings &rarr; Cloud Sync** you control when syncs happen:

| Option | What it does |
|--------|--------------|
| **Auto Sync** | Sync automatically whenever your data changes. |
| **Sync on Launch** | Run a sync when the app starts. |
| **Sync on Resume** | Run a sync when you return to the app. |
| **Sync Now** | Trigger a sync manually. |
| **Last Sync** | Shows when the last successful sync ran. |

[More about the Settings page &rarr;](guide/settings.md)

## What Syncs Between Devices

Your dive log always syncs: dives, sites, trips, buddies, gear, and everything
else you record. Settings are split three ways. Most follow your **diver
profile** to every device, a few are **shared** by everyone using the library,
and some stay on **the device** where you set them.

### Settings Belong to a Diver

Most settings are saved with the active diver profile rather than with the app.
Switching to another diver switches to that diver's settings, and another device
shows your settings when it has the same diver profile open.

A device that was set up with its own diver profile before it joined sync keeps
that profile, even when it has the same name as yours. When two profiles have
the same name (capitals and extra spaces are ignored), **Settings &rarr; Cloud
Sync** shows a **Duplicate diver profiles** banner after the sync. If you named
them differently, rename one to match the other and the banner appears. Tap
**Merge** to combine them: dives and data move onto one profile, and that
profile's settings are the ones every device uses from then on. Submersion keeps
your default diver, or the oldest profile if none is the default. You can undo
the merge right after it finishes.

### Synced With Your Diver Profile

The pSCR ratio and **Keep overlays in view when zooming** used to stay on each
device. After updating, a diver profile that has no value yet takes this
device's setting if you had changed it from the default.

| Area | Settings |
|------|----------|
| **Units** | Unit system and every individual unit, gas consumption display, gas calculations, default water type, default currency, visibility scale, coordinate format, time and date format |
| **Language** | App language, place name language |
| **Decompression** | Gradient factors, CNS calculation, ppO2 limits, CCR setpoints, data source preferences (NDL, deco stop, TTS, GTR, and CNS sources), narcosis (O2 is narcotic, END limit), ascent planning, GTR reserve pressure, ascent-rate warning levels, last stop depth and stop increment, the pSCR ratio in the dive planner |
| **Safety** | Post-dive safety review and its rules, flying after diving preset, equipment condition thresholds and rules |
| **Appearance** | Color theme, map style, color accents |
| **Appearance, per section** (Dives, Sites, Trips, Certifications, Courses, and so on) | List view, list fields and field presets, card coloring, map backgrounds on cards, Show Details Pane, profile panel in table view, data source badges, diver figure, dive and site detail section order and visibility |
| **Dive profile chart** | Right Y-axis metric, default visible metrics, max depth, pressure threshold and gas switch markers, gas timeline, ceiling, ascent rate colors, NDL and deco stops on the profile, tissue display, Keep overlays in view when zooming |
| **Dive defaults and imports** | Default dive type, tank, and start pressure, applying the default tank to imports, auto-tagging imports, auto site matching, tank pressure at surfacing, grouping trips in the dive list |
| **Other** | Items hidden from this profile, hidden built-in tank presets, emergency region and hidden chambers, 3D seascape appearance |

### Synced for Everyone Using the Library

These are not tied to a diver. Every profile on every connected device shares
them.

- **Share new sites and trips by default**
- **Trimix Mixer** templates, gas prices, and fill settings (listed under
  **Settings &rarr; Manage**)
- **MOD calculator** inputs
- **Gear arrangement**
- **Photos & Media:** **Upload quality** for photos and video, the media library
  view and sort order, and **Automatically re-link exact matches**
- **Adobe Lightroom:** **Albums to scan** and **Check for new photos
  automatically**, for each connected Adobe account. Signing in to Adobe still
  happens on each device.

### Synced as Part of Your Library

- Everything you add under **Settings &rarr; Manage**: dive types, site types,
  dive roles, tank presets, weight presets, transmitters, service types, trip
  checklist templates, pre-dive checklists, near-miss log entries, species, tags,
  and saved queries. The built-in entries come with every installation, so only
  the ones you create or change travel between devices.
- Your diver profile details: personal information, medical information,
  insurance, and emergency contacts.
- Dive computers you have added. The Bluetooth pairing stays on each device, so
  each device connects to the computer on its own.
- CSV import presets.

### Stays on This Device

| Area | Settings |
|------|----------|
| **Notifications** | Service reminders on or off, reminder schedule, reminder time, trip service lead time. They follow the device's own permission to show notifications. |
| **App Security** | App Lock, unlock with biometrics, auto-lock, database encryption |
| **Cloud Sync** | Which backend you use and its credentials, Auto Sync, Sync on Launch, Sync on Resume |
| **Backup & Restore** | Automatic backups, frequency, how many backups to keep, backup location, cloud backup |
| **Database Storage** | Where the database file is kept |
| **Updates** | Automatic updates, update channel |
| **Appearance** | Light or dark mode, **Navigation layout** and **Always hide labels**, Display size, the Home screen layout (status chips and home cards) |
| **Photos & Media** | Show source badges on thumbnails, Upload photos automatically, uploading on cellular |
| **Dive computers** | Bluetooth pairing, Sync dive computer clocks |
| **Other** | Which diver is active, Data quality checks, the O2 cell unit in chart options, CSV export units, your sign-ins to other services (Garmin, Suunto, divelogs.de, Adobe Lightroom, and media storage logins), which dive detail sections are expanded, which trips are collapsed in the dive list, Debug mode |

Changing a setting that stays on the device never changes it on another
device, and a sync never overwrites it. A device that joins your library keeps
its own values. When a diver is new to the device, that diver's service
reminders (on or off, the reminder schedule, the reminder time and the trip
service lead time) and light or dark mode start at their defaults there.

<div class="tip">
<strong>Upload quality syncs, uploading does not.</strong> Each device decides for
itself whether to upload photos automatically and whether to use cellular data,
so you can let a tablet on Wi-Fi do the uploading while your phone waits.
</div>

### When Changes Show Up

A change you make to your diver's settings appears on your other devices after
their next sync, without restarting the app. Most shared settings do the same.
The Trimix Mixer and the media library preferences can need a restart of
Submersion, or reopening that screen, before they show a change made on another
device.

<div class="tip">
<strong>Change settings on one device at a time.</strong> Let it sync before you
change settings on another device. If two devices change settings before either
has synced, the most recent change wins.
</div>

## Switching or Removing a Backend

If you switch a device from one backend to another, Submersion confirms first:

> **Switch sync backend?** &mdash; Your data is not moved off the old backend; it
> stays there until you delete it. After switching, this device's next sync
> combines its data with whatever already exists on the new backend. Your other
> devices keep using the old backend until you switch each of them too.

Two things to remember:

- **Switching is per-device.** Each device keeps using its current backend until
  you switch it individually.
- **Nothing is deleted automatically.** Your old data stays in the previous
  storage until you remove it yourself.

For S3-compatible storage, you can clear the connection on a device with
**Remove Configuration** on the S3 settings screen. This forgets the endpoint and
keys on that device; it does not touch the data already in your bucket.

## Security & Privacy

- **Credentials stay on the device.** Endpoints, bucket names, and access keys are
  stored in your platform's secure keychain &mdash; not in the dive database, and
  never transmitted to Submersion.
- **Your data lives in your storage.** The shared library is held in the cloud
  account you control. Anyone who has your storage credentials can read it, so keep
  them safe and scope them narrowly (see step 3 of the R2 example below).
- **Encrypted in transit.** Submersion talks to S3-compatible storage over HTTPS.
  If you enter a plain `http://` endpoint, the app warns you that credentials and
  dive data will travel unencrypted &mdash; only do this on a trusted local network.
- **Encrypted at rest.** Cloudflare R2, like most S3 providers, automatically
  encrypts stored objects at rest. Submersion does not add its own separate
  encryption layer on top, so a private bucket and a tightly scoped access token
  are your main protections.

---

## Example: Cloudflare R2 (S3-Compatible)

[Cloudflare R2](https://developers.cloudflare.com/r2/) is a convenient
S3-compatible backend: it has a generous free monthly tier, charges no egress
fees, and works on every platform Submersion supports. This walkthrough sets it
up end to end.

<div class="tip">
<strong>Terminology:</strong> R2 has no separate "tenancy" to create &mdash; your
<strong>Cloudflare account</strong> is the tenant. Your account's ID becomes part
of the storage endpoint (<code>https://&lt;account-id&gt;.r2.cloudflarestorage.com</code>),
which Cloudflare shows you when you create your keys &mdash; so you will not need
to look it up separately.
</div>

### 1. Enable R2

1. Sign in at [dash.cloudflare.com](https://dash.cloudflare.com/) (create a free
   account if you do not have one).
2. In the sidebar, go to **Storage & databases &rarr; R2 &rarr; Overview**.
3. Complete the checkout flow to add an R2 subscription. R2 includes a free
   monthly allowance; you may be asked to put a payment method on file before the
   bucket tools unlock.

### 2. Create a Bucket

1. On the R2 page, select **Create bucket**.
2. Enter a **bucket name** &mdash; lowercase letters, numbers, and hyphens; 3&ndash;63
   characters; it cannot start or end with a hyphen. For example, `my-dive-log`.
3. Optionally choose a **Location** to keep data near you. For strict
   data-residency needs, choose **Specify jurisdiction** (for example, **EU**)
   instead &mdash; note that this changes your endpoint hostname (see
   **Jurisdiction Endpoints** below).
4. Create the bucket and note its name &mdash; you will enter it in Submersion.

### 3. Create API Credentials (Access Keys)

1. From the R2 **Overview** page, open **API Tokens** (the **Manage R2 API Tokens**
   link in the account details area).
2. Select **Create Account API token**. An *account* token stays valid until you
   revoke it, which is what you want for a long-lived sync setup.
3. For **Permissions**, choose **Object Read & Write** &mdash; this lets Submersion
   read, write, and list objects, but not manage your other buckets.
4. Choose the option to apply the token to **specific buckets**, and select the
   bucket you created. (Limiting a token to one bucket is good security hygiene.)
5. Create the token. Cloudflare now shows you three values:
   - **Access Key ID**
   - **Secret Access Key**
   - **S3 endpoint** (`https://<account-id>.r2.cloudflarestorage.com`)

<div class="warning">
<strong>Copy the Secret Access Key now.</strong> Cloudflare displays it only once.
Copy all three values somewhere safe before leaving the page &mdash; if you lose
the secret, you will have to create a new token.
</div>

<div class="screenshot-placeholder">
  <strong>Screenshot 3: R2 token credentials</strong><br>
  <em>The Cloudflare screen showing the Access Key ID, Secret Access Key, and S3 endpoint after a token is created.</em>
</div>

### 4. Configure Submersion (First Device)

1. In Submersion, open **Settings &rarr; Cloud Sync** and choose
   **S3-Compatible Storage**.
2. Fill in the four main fields:

| Field | What to enter |
|-------|---------------|
| **Endpoint URL** | The S3 endpoint from step 3, e.g. `https://<account-id>.r2.cloudflarestorage.com` |
| **Bucket** | The bucket name from step 2, e.g. `my-dive-log` |
| **Access Key ID** | From step 3 |
| **Secret Access Key** | From step 3 (tap the eye icon to reveal and check it) |

3. Leave the **Advanced** section alone. Submersion auto-detects the correct
   **Region** (`auto`) for R2 and selects the right addressing mode automatically;
   the default **Key prefix** (`submersion-sync/`) keeps Submersion's files tidy
   inside the bucket.
4. Tap **Test Connection**. Submersion writes a tiny probe object to the bucket,
   reads it back, and deletes it to confirm the credentials work. You should see
   **Connection successful**.
5. Tap **Save**.
6. Run **Sync Now** to seed your library into the bucket.

<div class="screenshot-placeholder">
  <strong>Screenshot 4: S3-Compatible Storage form</strong><br>
  <em>The S3 configuration screen with the Endpoint, Bucket, and key fields filled in.</em>
</div>

### 5. Repeat on Your Other Devices

Enter the **same four values** on each additional device
(**Settings &rarr; Cloud Sync &rarr; S3-Compatible Storage**), tap
**Test Connection**, then **Save**. On the first sync, choose **Merge and Sync**
at the **Combine Libraries?** prompt. All of your devices now share one log
through R2.

### Jurisdiction Endpoints

If you created the bucket with a jurisdiction for data residency, use the matching
endpoint hostname in the **Endpoint URL** field:

| Jurisdiction | Endpoint |
|--------------|----------|
| Default | `https://<account-id>.r2.cloudflarestorage.com` |
| EU | `https://<account-id>.eu.r2.cloudflarestorage.com` |
| FedRAMP | `https://<account-id>.fedramp.r2.cloudflarestorage.com` |

### R2 Troubleshooting

| Problem | What to try |
|---------|-------------|
| **Test Connection fails with an access or signature error** | Re-check the Access Key ID and Secret Access Key for stray spaces. Confirm the token's permission is **Object Read & Write** and that it is scoped to *this* bucket. |
| **Test Connection reports a region problem** | Open the **Advanced** section and check the **Region** field; for R2 it should auto-detect to `auto`. Re-run the test. |
| **The endpoint is rejected as invalid** | The endpoint must be a full `https://` URL with nothing after the hostname &mdash; just `https://<account-id>.r2.cloudflarestorage.com`, not a `/bucket` path. The bucket name goes in its own field. |
| **A dive appears twice after adding a device** | That dive was logged separately on both devices before they were merged. Delete the duplicate; the removal syncs to the others. |
| **No dives appear on the new device** | Make sure you tapped **Merge and Sync** at the Combine Libraries prompt, and that every device uses the same bucket and keys. |
