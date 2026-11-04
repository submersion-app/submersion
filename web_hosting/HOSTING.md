# Hosting the Submersion web app

This folder is the Submersion web app as static files: the same dive log
you install on a phone or a computer, running in a browser and reading your
dives from your own sync store. Nothing here runs on a server. Copy the
folder to any web host that serves files, open its address, and connect the
store you already sync with.

You do not need to host it to use it: Submersion serves its own copy at
<https://web.submersion.app>, the one site that can open the Google Drive
library the installed apps sync to. Host your own when you want the app at
an address you control.

The user guide for the web app, with the connection steps for each store,
is at <https://submersion.app/guide/#/web-app> (source:
<https://github.com/submersion-app/submersion/blob/main/docs/user/web-app.md>).

## HTTPS is required

Browsers only give a page lasting storage and the other APIs the app needs
on a secure address. Serve the folder over HTTPS; `http://localhost` is the
one exception, for trying it on your own machine.

## Two headers, recommended

Send these two response headers on every file:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: credentialless
```

They make the page "cross-origin isolated", which unlocks the fastest
browser storage: the database runs in a web worker over the browser's
private file system. Chrome only gets that with the headers. Without them
the app still works, on a slower path.
Settings, Cloud Sync shows a **Browser storage** row naming what is in
use: *Browser file storage*, *Browser database (slower)* where the browser
has no file storage or, in Chrome, the headers are missing, or a warning
that nothing is saved when the browser gives the site no lasting storage
at all.

`credentialless` rather than `require-corp`: the stricter mode blocks every
image and map tile from a host that does not send its own cross-origin
headers, so photos linked from the web and map tiles would stop loading.
Switch to `require-corp` only if a policy on your side demands it, and
expect those to break.

**Google Drive and the opener policy.** Google's sign-in opens a popup
that has to report back to the page, and `same-origin` cuts that link, so
the sign-in never completes. If your users connect Google Drive, send
`Cross-Origin-Opener-Policy: same-origin-allow-popups` instead. That mode
does not make the page cross-origin isolated, so the database runs on the
slower storage path described above; the other stores are unaffected
either way.

The files for each host below already carry the headers, with the Google
Drive alternative noted beside them.

## Hosts

### A folder behind nginx

Copy the folder to the server and drop `nginx.conf` into
`/etc/nginx/conf.d/` (it is a complete `server` block serving
`/usr/share/nginx/html`; change `root` if the files live elsewhere). It sets
the two headers, serves `.wasm` with the right type and sends unknown paths
to `index.html`. Terminate HTTPS in front of it or add `listen 443 ssl` and
your certificate.

### Caddy

`Caddyfile` is a complete site. Replace `dive.example.com` with your host
name and `/srv/submersion-web` with the folder; Caddy obtains the
certificate on its own.

### Cloudflare Pages and Netlify

Upload or deploy the folder as the site root. Both read `_headers` from the
root and send the two headers on every file. Nothing else to configure.

### GitHub Pages

Push the folder to a Pages branch or folder. GitHub Pages cannot send custom
headers, so the app runs on the slower storage path described above; it is
otherwise complete. Project sites live under a sub-path
(`https://you.github.io/repo/`): build with
`--base-href /repo/` (see `scripts/build_web.sh` in the repository) or use a
user site at the root.

### An S3 website bucket

Enable static website hosting on the bucket, upload the folder, and put a
certificate-bearing CDN (CloudFront, or your provider's equivalent) in
front, since the website endpoint itself is plain HTTP. The endpoint sends
no custom headers, so the app runs on the slower storage path.

### A container

`Dockerfile` builds an nginx image with the folder inside. From this folder:

```
docker build -t submersion-web .
docker run --rm -p 8080:80 submersion-web
```

Then open `http://localhost:8080`. Anywhere but your own machine, put a
TLS-terminating proxy in front. No image is published; you build it from
the bundle.

## Letting the app reach your store

A page may only call another site when that site allows it, through CORS
headers in its responses. Your sync store must allow requests from this
site's address (its origin, such as `https://dive.example.com`). The app's
**Check connection** step tells you when the store refuses browser
requests and shows the exact rule to add, with this site's address filled
in and a **Copy rule** button. The user guide lists the rule for AWS S3,
Cloudflare R2, Backblaze B2, MinIO, Nextcloud and plain WebDAV servers.
Dropbox needs nothing. Google Drive needs a web client id from your own
Google Cloud project, created once (the guide walks through it), and on
your site sees only a Drive library your site starts: Google keeps each
project's Drive folder apart, so the library the installed apps sync to
Google Drive opens only on Submersion's own site. Libraries in Dropbox, S3
and WebDAV open from any site. A photo store kept in a different bucket or
server from the sync store needs the same rule, or its photos stay as
placeholders in the browser.

## What to know before you share the address

- **Credentials live in the browser.** A full connection holds the store's
  key and secret in the page while it is open. They are forgotten when the
  tab closes unless the user turns on **Remember on this device**, which
  keeps them in the browser's local storage for this site. Use a key scoped
  to the sync prefix, not an account-wide one.
- **The database is not encrypted at rest.** The browser isolates it to
  this site, but anyone with the operating system account and the browser
  profile could read it. **Forget this device**, in Settings, Cloud Sync,
  wipes the database, the credentials and the device identity.
- **The site is static.** There is no server code, no account and no data
  at the host: dive data travels only between the browser and the user's
  store. The page does load two things from Google: its sign-in script, which
  the Google Drive support brings in on every visit, and fallback fonts for
  characters the app's own fonts lack. Neither carries dive data.
- **The Google client id is public by design.** A web client id has no
  secret; restricting it to this site's address in Google Cloud is what
  protects it.
- **The `demo/` folder is the sample logbook.** It is the made-up dive log
  behind **Explore with sample data**, about 21 MB with its photos, and the
  site reads it from its own address. Delete the folder to hide sample mode;
  nothing else depends on it.

## Updating

Replace the files with the next release's bundle. There is no service
worker, and the hosting files mark everything that keeps its name across
releases `no-cache`: `index.html`, `flutter_bootstrap.js`, `main.dart.js`,
`version.json`, the two workers and `sqlite3.wasm`. A browser revalidates
them on the next load and picks the new bundle up at once, which matters
because the app, its workers and the SQLite module must all come from one
release. On a host that cannot set headers (GitHub Pages, an S3 website
endpoint) a returning visitor may keep last release's files until their
browser revalidates on its own; a hard reload fetches the new ones. The
app shows its version in Settings, About.
