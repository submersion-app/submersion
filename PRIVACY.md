# Privacy Policy

**App:** Submersion
**Last Updated:** 2026-09-19

## Data Collection

Submersion is a local-first dive logging application. All data you enter is stored on your device. The app may collect and store the following types of information based on your usage:

- **Dive logs** — date, time, depth, duration, temperature, notes, and other dive parameters
- **Dive sites** — location names, GPS coordinates, descriptions, and conditions
- **Diver profile** — name, certification information, and dive preferences
- **Gear inventory** — equipment names, serial numbers, purchase dates, and service records
- **Buddies** — names and contact information for dive partners
- **Photos and videos** — media attached to dive entries, selected from your device library
- **Dive computer data** — depth profiles, tank information, and telemetry downloaded via Bluetooth

## Data Storage

All data is stored locally on your device in a SQLite database. Submersion
does not operate any remote servers. No data is ever transmitted to a server
owned or operated by Submersion, because no such server exists.

**Encrypting that database is optional and is off unless you turn it on.**
You can enable encryption at rest in Settings, under Security, which protects
the database with a passphrase and can unlock it with your fingerprint or
face. Until you do, the database is an ordinary unencrypted file on your
device, protected by your device's own lock screen and storage encryption but
not by Submersion.

Data can leave your device only to storage you already own, and only when you
choose to set that up. There are two separate features that do this, and they
protect your data differently. The difference matters, so it is spelled out
below.

## Backup and Sync

Optional. Off until you configure it.

Backup and sync write your dive log to cloud storage you control: Google
Drive, Dropbox, iCloud, or S3-compatible storage. You choose the provider and
connect your own account.

Whatever you choose, the data is stored in your own account, under your own
control, and is transmitted over HTTPS. Submersion has no access to your cloud
storage beyond the files the app itself creates there.

### Encryption is optional here too, and off by default

Sync offers end-to-end encryption, which you turn on in Settings by setting a
passphrase. You are given a recovery code at that point, because without the
passphrase or the recovery code the data cannot be recovered by anyone,
including us.

**With end-to-end encryption on:** the dive log is sealed with AES-256-GCM
before it leaves your device, using a key derived from your passphrase. The
key is never uploaded and is never sent to Submersion or to your storage
provider. Google, Dropbox, Apple and any S3 operator see only encrypted files
and cannot read your dive log, your notes or your locations.

**With end-to-end encryption off, which is the default:** your dive log is
uploaded as ordinary readable files. It is protected in transit by HTTPS and
by whatever security your storage provider applies, but your storage provider
can access its contents in the same way it can access any other file you keep
there.

If your dive log matters to you, turning on end-to-end encryption before you
enable sync is worth the minute it takes.

## Photo and Video Upload

Optional. Off until you attach a media store.

Separately from backup and sync, Submersion can upload the photos and videos
you attach to dives, so that your media is available on your other devices.
This uses the same providers: Google Drive, Dropbox, iCloud or S3-compatible
storage, in an account you connect.

**Photos and videos uploaded this way are not encrypted by Submersion.** They
are transmitted over HTTPS and stored as ordinary files in your cloud account,
which means your storage provider can access them in the same way it can
access any other photo you keep there. Turning on end-to-end encryption for
sync does not cover them: media upload has no encryption option.

If you do not attach a media store, your photos and videos are never uploaded.
Dive media is otherwise referenced in place: Submersion points at the photo in
your device's own photo library rather than copying it into the app.

## Information About Other People

Some of what Submersion stores is not about you. A dive log naturally records
the people you dive with, and Submersion may hold the following about them:

- **Name**, for dive buddies, instructors and divemasters
- **Email address and phone number**, if you add them to a buddy record
- **Profile photo**, if you add one to a buddy record
- **Handwritten signature**, if an instructor or buddy signs a dive in the app
- **Certification details**, if you record them for a buddy
- **Their presence in your photos and videos**

You may have imported some of this from your device's contacts.

**If you enable backup and sync, this information leaves your device along
with the rest of your dive log.** It goes only to storage you control. If you
have also turned on end-to-end encryption, your storage provider cannot read
it; if you have not, which is the default, it is uploaded in readable form.
Either way it does leave your device, and the people it describes have not
agreed to that, because they were never asked.

This is the strongest reason to turn on end-to-end encryption. The data you
are uploading is not all yours to expose.

**If you attach a media store, photos and videos containing other people are
uploaded without encryption,** as described above, and your storage provider
can access them.

Certification card images deserve a specific mention. If you photograph a
certification card, yours or someone else's, that image carries a full name, a
certification number, an issuing agency and a date. It is stored in your dive
log and is included in backup and sync like any other part of it.

Submersion never transmits any of this to Submersion, to any other user, or to
any third party for their own purposes. It travels only to the storage account
you have connected. Even so, you are the one deciding to record another
person's details and to sync them, so please consider:

- Ask before you store someone's contact details, photograph or signature
- Ask before you record certification details that belong to them
- Delete a buddy record, which deletes what it holds about them, if they ask
  you to

## Online Features and Third-Party Services

Several Submersion features answer questions that cannot be answered on your
device: what a place is called, what the weather was on the day you dived,
what lives on a reef, how deep the seafloor is. These features work by asking
a public service, which means sending it a question.

### What happens without you doing anything

One thing only. Submersion checks GitHub for a newer version of the app.
This sends nothing about you or your diving. GitHub sees a request from your
IP address asking what the latest version is.

### Features that send a dive site's coordinates

If you open one of the features below, Submersion sends the relevant
coordinates to the service listed beside it. Nothing else is sent: no name, no
account, no device identifier, and nothing that identifies you or links one
request to another. The service sees a location and the IP address the request
came from.

| What the feature does | Services it asks |
|---|---|
| Turn coordinates into a place name, or a place name into coordinates | OpenStreetMap Nominatim |
| Draw maps and satellite imagery | OpenStreetMap, OpenTopoMap, Esri ArcGIS, swisstopo |
| Look up the weather on the day of a dive, and a site's elevation | Open-Meteo |
| Find tide stations near a site | NOAA |
| Identify and suggest marine species | iNaturalist, GBIF |
| Show reef health, habitat and marine protected areas | NOAA Coral Reef Watch, PacIOOS, UNEP-WCMC, Esri ArcGIS |
| Show seafloor depth and 3D terrain | EMODnet, NOAA NGDC, GMRT, swisstopo |

These are independent organisations with their own privacy policies. They are
not partners of Submersion, receive no payment from us and send us nothing.
We ask them a question on your behalf and show you the answer.

If you would rather not contact them, do not open those features. Maps can
also be used offline by downloading a region in advance, which avoids further
tile requests for that area.

### Services you connect yourself

If you choose to connect one of these accounts, Submersion communicates with
that provider using credentials you supply, and only then:

| Service | What it is for |
|---|---|
| Garmin Connect | Downloading your dives from Garmin |
| Suunto (Sports Tracker) | Downloading your dives from Suunto |
| Adobe Lightroom | Reading photos from your Lightroom library |
| A network drive or server you name | Reading media you keep on your own storage |

Each is optional, off until you set it up, and can be disconnected at any
time. Your credentials for these services are held in your device's secure
keychain and are never sent to Submersion.

## Health Data

On iOS, Submersion can optionally read dive workout data from Apple HealthKit. This data is:

- **Read-only** — Submersion reads existing dive workouts but does not write to HealthKit
- **Never transmitted off device** — HealthKit data stays on your device
- **Never shared with third parties**

This feature is not currently available on Android.

## Data Sharing

Submersion does not sell your data, trade it, or hand it to anyone for their
own purposes. Specifically:

- No analytics or tracking services
- No advertising networks
- No account creation required
- No third-party SDKs that collect user data
- No data transmitted to any Submersion server, because none exists

Your dive log leaves your device only through the optional backup, sync and
media upload features described above, and only to a storage account you
connect and control.

Separately from that, the online features described above send coordinates to
public map, weather, tide and marine data services in order to answer a
question you asked. That is a real transfer and we would rather name it than
hide it behind the word "never". It is limited to coordinates, it carries
nothing that identifies you, and it happens only when you open the feature
that needs it.

## Device Permissions

Submersion requests the following permissions only as needed for specific features:

| Permission | Purpose |
|---|---|
| **Bluetooth** | Discover and communicate with BLE dive computers |
| **Location** | Tag dive sites with GPS coordinates; required for BLE scanning on Android 11 and below |
| **Photos and media** | Attach photos and videos to dive entries |
| **Media location** | Read GPS data from photo EXIF metadata to suggest dive site locations |
| **Contacts** | Select dive buddies from your device contacts |
| **Notifications** | Send gear maintenance service reminders |
| **Exact alarms** | Schedule precise gear maintenance reminders |

All permissions are optional. The app will function without them, though related features will be unavailable.

## Data Deletion

- You can delete any or all of your data from within the app at any time.
- Uninstalling Submersion removes all locally stored data from your device.
- Deleting a buddy deletes what Submersion holds about that person, including
  their photo and contact details.
- Backups, synced data and uploaded media can be deleted directly from the
  cloud storage account you connected, whichever provider it is.

## Children

Submersion is not directed at children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided data through the app, please contact us so we can take appropriate action.

## Changes to This Policy

This privacy policy may be updated from time to time. Changes will be reflected by updating the "Last Updated" date at the top of this document.

## Contact

If you have questions or concerns about this privacy policy, you can reach us at:

- **Email:** privacy@submersion.app
- **GitHub:** Open an issue at [github.com/submersion-app/submersion](https://github.com/submersion-app/submersion)

## Open Source

Submersion is open-source software. The full source code is available at:

[https://github.com/submersion-app/submersion](https://github.com/submersion-app/submersion)
