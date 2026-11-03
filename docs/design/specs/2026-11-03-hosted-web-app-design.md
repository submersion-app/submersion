# Submersion's own hosted web app (issue #4161)

## Intent

The web app (issue #4121, PR #4142) ships as a self-hosted bundle only
(web app spec, decision 4). Most divers will never host a folder of static
files, and only Submersion's own site can sign in to the Google Drive
library the installed apps sync (decision 19). This adds Submersion's own
copy at **`https://web.submersion.app`**, updated on every stable release
with the same bundle the release ships.

Success: after a stable release is promoted, `web.submersion.app` serves
that release's bundle, Google Drive signs in there without asking for a
client id, and the user guide sends readers there first.

## Decisions

| # | Question | Decision |
| --- | --- | --- |
| 1 | Address | `https://web.submersion.app`, a subdomain, not a path on `submersion.app`. A browser keeps storage per origin, so a path would share local storage (including S3 keys kept by **Remember on this device**) with every page of the website and guide (owner's choice) |
| 2 | Host | GitHub Pages, served from the `main` branch root of a new public repository, `submersion-app/web`, with `web.submersion.app` as its custom domain and HTTPS enforced. The website repository is not touched. Pages sends no isolation headers, so Chrome runs the slower IndexedDB storage, as `web_hosting/HOSTING.md` says; it also sends no opener policy, so Google's sign-in popup works |
| 3 | When it updates | On each stable release, never on a beta (owner's choice). The site then matches the version the stores ship, the version installed apps sync with |
| 4 | Which bundle | The one release `Submersion-<tag>-Web.zip`, built with Submersion's Google web client limited to `https://web.submersion.app` (owner's choice). The client is already used only at its authorised addresses (`GoogleDriveClientConfig.builtInWebClientIdFor`), so a self-hosted copy of the same zip still asks for its own client id. No second build: the site runs the exact bundle that was tested as a beta and promoted |
| 5 | Who creates the Pages repository | The builder, with `gh` (owner's choice). The owner does the steps that need their accounts: the Google client, the consent screen, DNS, and the deploy token |
| 6 | Website link | None in this change. The user guide names the address; a link on the `submersion.app` pages is left for later (owner's choice) |
| 7 | A bundle without the Google client | Deployed anyway, with a warning in the run (owner's choice). The client goes in when the beta is built, so a release whose beta was built before `GOOGLE_WEB_CLIENT_ID` was set, or an older release, carries none; on the site Google Drive then asks for a client id until the next release. A release with no `Web.zip` at all (before PR #4142) cannot be deployed and fails with that reason |
| 8 | Rolling back | A manual run refuses a release older than the one the site serves unless its `force` input is ticked (owner's choice). Every visitor's library lives in their browser on the one origin, already moved to the newer schema; an older release meets it with `DatabaseVersionMismatchException` and the visitor cannot update their way out. The docs say so beside the input |
| 9 | How the deploy authenticates (found during setup) | A fine-grained personal access token for `submersion-app/web` only, Contents read and write, as `beta.yml` publishes with `BETA_BUILDS_TOKEN` (owner's choice). The organization turns deploy keys off for every repository, so the deploy key first planned cannot be added. The token goes to git as an HTTP header through its environment config, never in a URL or a file; it expires and must be renewed |

## How it works

### Building the client in

`build-all.yml`'s `build-web` job passes two values to
`scripts/build_web.sh`:

- `GOOGLE_WEB_CLIENT_ID` from the repository variable
  `vars.GOOGLE_WEB_CLIENT_ID`. A web client id is public by design (the
  hosting guide says so), so a variable, not a secret.
- `GOOGLE_WEB_CLIENT_ORIGINS` set to `https://web.submersion.app`, written
  in the workflow.

When the variable is empty (a fork, or before the owner has created the
client), the job builds exactly as today, without the client. Only the
release build changes: the CI web build and smoke jobs stay client-free.

### Deploying

A new reusable workflow, `.github/workflows/deploy-web.yml`, with
`workflow_call` (input: the stable tag) and `workflow_dispatch` (the tag,
plus a `force` checkbox, for a redeploy or a rollback):

1. **Configured?** When the `WEB_DEPLOY_TOKEN` secret is absent, the job
   writes a notice and succeeds without deploying, so releases cut before
   the setup is finished do not fail or open alert issues.
2. **Fetch** `Submersion-<tag>-Web.zip` from that tag's GitHub release
   in this repository. Refuse a tag with a pre-release suffix (anything
   after the version with a `-`), and fail with the reason when the
   release has no `Web.zip`.
3. **Stage** with a new script, `scripts/web/stage_hosted_site.py`: unzip
   into an empty folder, run `scripts/check_web_bundle.py` on it, then add
   `CNAME` (`web.submersion.app`) and `.nojekyll`. It also checks the
   compiled app carries the client id and the site's origin (both are
   string constants in `main.dart.js`). When either is missing it prints a
   GitHub warning annotation and carries on (decision 7). Python, with a
   `_test.py` beside it run in CI's Script Tests job under the guards'
   coverage, as the other web scripts are.
4. **Not older, unless forced**: fetch `main` of `submersion-app/web`
   (depth 1, with the deploy token) and read its `version.json`, which
   Flutter writes into every bundle (`version` and `build_number`). When
   the staged bundle's version is older, refuse unless `force` is set
   (decision 8). An empty repository, or one with no `version.json`,
   passes. The comparison lives in the staging script, so it is tested.
   A promote never sets `force`; its tag is always the newest.
5. **Publish**: commit the staged folder as a single orphan commit
   ("Deploy Submersion <tag>") and force-push it to `main` of
   `submersion-app/web` over HTTPS with the deploy token. One commit, replaced
   each release, so the Pages repository never accumulates a history of
   bundles of about 160 MB each (the sample logbook, the compiled app and
   the renderer).

Callers:

- `promote.yml`: a `deploy-web` job after `promote`, with the promoted
  tag. It joins `notify-failures`' `needs`, so a failed deploy is
  reported like the other promote steps.
- `release.yml`: the legacy hotfix path (a tag pushed by hand). A
  `deploy-web` job after `create-release`, only for a tag with no
  pre-release suffix and only when the precheck let the rebuild proceed
  (a promoted tag is deployed by `promote.yml`).

### Docs

- `docs/user/web-app.md`: the opening and "Opening it" name
  `https://web.submersion.app` as the place to open it; self-hosting stays
  as the second way. The Google Drive section already describes
  "Submersion's own site"; it names the address.
- `web_hosting/HOSTING.md`: one line that Submersion hosts its own copy
  at the address, for anyone who does not need to host one.
- `docs/developer/web.md`: the official site, how it deploys, and the
  rollback.
- A new `docs/developer/web-site-setup.md`: the one-time setup, each step
  with who does it and the exact commands. Listed in
  `docs/developer/README.md` and linked from `release-secrets-setup.md`.

## One-time setup (owner, outside the repository)

1. Google Cloud, in the project that holds the installed apps' clients:
   create an OAuth client of type **Web application** with
   `https://web.submersion.app` as an authorised JavaScript origin. Set its
   id as the repository variable `GOOGLE_WEB_CLIENT_ID`. Do this first:
   the client goes in when a beta is built, so only betas built after the
   variable is set carry it, and only their promotion gives the site
   Google Drive sign-in.
2. OAuth consent screen: confirm it is published (in production, not
   testing) and that `submersion.app` is an authorised domain. The
   installed apps already sign in through this project, so it is likely
   published already; the new origin may prompt Google to re-check the
   branding.
3. DNS: a `CNAME` record for `web` pointing at `submersion-app.github.io`.
4. Deploy token: a fine-grained personal access token for
   `submersion-app/web` alone with Contents read and write, stored as the
   secret `WEB_DEPLOY_TOKEN` (decision 9).
5. After the first deploy: in `submersion-app/web`, Settings, Pages,
   confirm the custom domain and tick **Enforce HTTPS** once the
   certificate is issued.

The builder creates `submersion-app/web` (public, a README on `main`) and
turns on Pages from `main` with the custom domain, as far as `gh` allows
before DNS exists.

## Goals

- A stable release reaches `web.submersion.app` with no manual step.
- The site serves byte-for-byte the release's web bundle, plus `CNAME`
  and `.nojekyll`.
- Google Drive signs in on the site with Submersion's client and sees the
  library the installed apps sync.
- A redeploy is one manual workflow run with a tag; a rollback is the same
  run with `force` ticked, and refused without it.

## Non-goals

- Cross-origin isolation headers (needs a host other than Pages, such as
  Cloudflare Pages; a later change if IndexedDB proves too slow).
- A beta or preview site.
- Links from the `submersion.app` website.
- Removing `HOSTING.md`, `nginx.conf` and the other hosting files from the
  hosted copy: they stay, so the site matches the release zip.

## Anti-goals

- A site that runs code the beta never ran (a second, untested build).
- A release that fails, or opens an alert, because the site's setup is
  not finished yet.
- A self-hosted copy that tries Submersion's client at its own address.

## Left to the builder

- The exact check in `stage_hosted_site.py` for the client id and origin
  in `main.dart.js` (a plain substring check is enough).
- Workflow details: runner, timeouts, the git identity of the deploy
  commit, the `concurrency` group (one deploy at a time, not cancelled).
- The wording of the docs.

My calls (not discussed with the owner): the deploy skipping, not failing, while unconfigured; the
legacy `release.yml` path also deploying; the bundle check before
publishing; reading the deployed version from the Pages repository's
`version.json` rather than from the commit message or the live site.
