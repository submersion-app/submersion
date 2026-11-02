# Submersion in a Browser

Submersion runs in a web browser: the same dive log, reading your dives
from the sync store you already use and keeping them in that browser. It
is for the moments you are not on a device that has Submersion installed,
or cannot install it: a work laptop, a friend's computer, a dive centre's
machine. You look at your dives, refine them, and the changes sync back to
your phone and your computer.

Nothing runs on a server. The site is a folder of static files that you,
or someone you trust, host; your data travels only between the browser
and your own store. Hosting it is described in the guide shipped inside
the bundle (`HOSTING.md` in `Submersion-<version>-Web.zip` on the
[releases page](https://github.com/submersion-app/submersion/releases)).

## Opening it

Open the address your self-hosted copy is served from. The first visit
asks which store holds your dives and how to reach it (below); after the
first sync the app opens on your dive list, as on any device.

If you would rather start without a store, **Continue without a sync
store** on that first screen runs the normal setup wizard and keeps a
logbook in that browser alone.

## What works, and what does not

Everything you do on a desktop works in a browser: the dive log and dive
details, profiles and decompression, sites, trips, equipment, buddies and
dive centres, certifications, statistics, insights, planning, compare,
data quality, rules, tags, the change log, settings, and sync itself.
File import and export use the browser's file picker and downloads;
printing and PDF export go through the browser; a dive site's location
comes from the browser's location prompt.

A browser has no hardware path and no files of its own, so these are not
offered, and the app says so where they would be:

- **Dive computer downloads**, over Bluetooth, USB or serial. Download on
  your phone or computer; the dives arrive in the browser by sync.
- **NFC** tags and gear passports, the **buddy card swap** over nearby
  devices, **Apple Health** and **Health Connect** imports, the **paper
  log scan**, the device **photo library**, and the **biometric lock**.
- **Background sync and reminders**. Sync runs while the tab is open.
- **Offline map tiles**. Maps load their tiles from the network.
- **Restoring a backup file**. The browser's data comes from your store;
  you can still download a backup (below).
- **Importing another app's database** (MacDive, Subsurface, Diving Log).
  Text and XML formats (UDDF, CSV, FIT, SSRF, DL7) import normally.
- **The sample logbook**, the **in-app updater** (the site shows its
  version; whoever hosts it updates the files) and **agent access**.

## Connecting your store

A page may only call another site when that site allows it, through
"CORS" headers in its responses. Your store must allow requests from the
address the app is served at (its origin, such as
`https://dive.example.com`). The connect screen's **Check connection**
tells you when the store refuses browser requests and shows the exact rule
to add, with your site's address filled in and a **Copy rule** button.
The rules below use `https://your-site` as that address.

Dropbox needs nothing. iCloud Drive has no browser interface and Git is
not offered in a browser in this release; the connect screen names both
as unavailable and suggests the alternatives.

### Amazon S3, Cloudflare R2 and other S3-compatible stores

Paste the same endpoint, bucket, key and secret as in the app. Add this
CORS rule to the bucket (AWS: the bucket's Permissions tab, "Cross-origin
resource sharing"; R2: the bucket's Settings, "CORS policy"):

```json
[
  {
    "AllowedOrigins": ["https://your-site"],
    "AllowedMethods": ["GET", "HEAD", "PUT", "POST", "DELETE"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag", "x-amz-request-id", "x-amz-version-id"],
    "MaxAgeSeconds": 3000
  }
]
```

Use a key scoped to the bucket and the sync prefix, not an account-wide
one: the browser holds it while the tab is open.

### Backblaze B2

```
b2 bucket update --cors-rules '[
  {
    "corsRuleName": "submersion-web",
    "allowedOrigins": ["https://your-site"],
    "allowedOperations": ["s3_get", "s3_head", "s3_put", "s3_post", "s3_delete"],
    "allowedHeaders": ["*"],
    "exposeHeaders": ["etag", "x-amz-request-id"],
    "maxAgeSeconds": 3600
  }
]' <bucket-name>
```

### MinIO

Recent MinIO sets the rule per bucket with the same JSON as S3:

```
mc cors set <alias>/<bucket> cors.json
```

Older MinIO sets allowed origins server-wide:

```
mc admin config set <alias> api cors_allow_origin="https://your-site"
mc admin service restart <alias>
```

### Nextcloud and ownCloud

Add the headers at the reverse proxy in front of Nextcloud (nginx shown;
the app prints the block for your server):

```nginx
location /remote.php/dav {
    add_header Access-Control-Allow-Origin "https://your-site" always;
    add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS, PROPFIND, PUT, DELETE, MKCOL, MOVE" always;
    add_header Access-Control-Allow-Headers "Authorization, Content-Type, Depth, Destination, Overwrite, If-Match, If-None-Match" always;
    add_header Access-Control-Expose-Headers "ETag" always;
    if ($request_method = OPTIONS) {
        return 204;
    }
}
```

### A plain WebDAV server (Apache)

```apache
<Location "/">
    Header always set Access-Control-Allow-Origin "https://your-site"
    Header always set Access-Control-Allow-Methods "GET, HEAD, OPTIONS, PROPFIND, PUT, DELETE, MKCOL, MOVE"
    Header always set Access-Control-Allow-Headers "Authorization, Content-Type, Depth, Destination, Overwrite, If-Match, If-None-Match"
    Header always set Access-Control-Expose-Headers "ETag"
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} OPTIONS
    RewriteRule ^(.*)$ $1 [R=204,L]
</Location>
```

A WebDAV server that answers plain requests but refuses `PROPFIND` looks
like a blocked store at first; Check connection tells the two apart and
shows the methods line to add.

### Dropbox

Choose Dropbox, sign in to Dropbox in the tab that opens, copy the code
Dropbox shows, and paste it back. Nothing to configure on Dropbox's side.

### Google Drive

The app's built-in Google sign-in belongs to the installed apps; a page
needs a client id of its own, from your own Google Cloud project, created
once:

1. In the [Google Cloud console](https://console.cloud.google.com/),
   create a project (or pick one) and enable the **Google Drive API**
   under APIs & Services.
2. Configure the **OAuth consent screen** for the project if it asks:
   external, with your own Google account as a test user is enough.
3. Under **Credentials**, choose **Create credentials**, then **OAuth
   client ID**, application type **Web application**. Under **Authorised
   JavaScript origins** add the address the app is served at, such as
   `https://dive.example.com`. No redirect URI is needed.
4. Copy the client id (it ends in `.apps.googleusercontent.com`). The app
   asks for it when you choose Google Drive in a browser; paste it there.

A web client id is public by design: it has no secret, and restricting it
to your site's address is what protects it. The browser's Google sign-in
lasts about an hour and cannot be kept across visits, so Google asks you
to sign in to the site on each visit; while the tab is open the app renews
quietly, and when it cannot, the sync status asks you to sign in again.

## Encrypted libraries

If your library is [encrypted](encrypted-sync.md), the connect screen asks
for the passphrase, as a new device does. It is kept only while the tab is
open unless you turn on Remember on this device (next).

## Remember on this device

By default the browser forgets your store's credentials, and the
passphrase, when the tab closes: the next visit asks again. **Remember on
this device**, on the connect screen and in Settings, Cloud Sync, keeps
them in the browser's storage for this site instead, lightly obscured,
not encrypted. Leave it off on a shared machine. For Google Drive the
remembered part is the client id; the sign-in itself cannot be kept.

## Where your dives live in the browser

The browser keeps your dives in storage the browser reserves for this
site, so they are there on the next visit without a fresh download.
Settings, Cloud Sync shows a **Browser storage** row naming what is in
use:

- *Browser file storage*: the fastest, and the usual case.
- *Browser database (slower)*: a browser without file storage. Everything
  works; large libraries take longer to open.
- A warning that nothing is saved after the tab closes: a browser that
  gives the site no lasting storage, such as some private windows. Sync
  before you leave.

Whoever hosts the site can send two headers that unlock the fastest
storage; the hosting guide covers it. Without them the app still works.

The database is not encrypted at rest in the browser. Anyone with the
same operating system account and browser profile could read it, which is
what Forget this device is for.

## Forget this device

**Forget this device**, in Settings, Cloud Sync, removes everything
Submersion keeps in that browser: the dive log, the credentials and
passphrase, and the device's identity in your sync mesh. Your other
devices keep their copies and their stores. Use it before you leave a
machine that is not yours. If the browser kept the database (another tab
still had it open), the page says so rather than pretending; close the
other Submersion tabs and try again.

Your other devices list the browser like any other peer, named after the
browser and operating system ("Chrome on Windows"); an iPad's Safari
reports itself as "Safari on macOS". Forgetting the browser from another
device works the same way as for any peer.

## Browsers

Current Chromium browsers (Chrome, Edge, Brave), Firefox and Safari. The
site must be served over HTTPS (or `http://localhost` on your own machine)
for the browser to give it lasting storage.

## Photos and media

Photos and documents already linked to your dives show in the browser
when the browser can reach their files: those synced through your store
or kept at a web address. Linking new media, replacing a link, scanning
and importing files are not offered in a browser; viewing and sharing
are.

## Downloads and backups

Every export (UDDF, CSV, PDF and the rest) is a download in the browser.
The Backups page offers one thing: **Download a backup**, a copy of your
dive log as a database file, named `submersion-backup-<date>-<time>.db`.
Restoring from a file is done in the installed app, not in the browser.
