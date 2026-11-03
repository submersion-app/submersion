# Submersion's Own Web Site

Submersion serves its own copy of the web app at
<https://web.submersion.app> (issue #4161; design in
[the spec](../design/specs/2026-11-03-hosted-web-app-design.md)). It is the
one place a browser can open the Google Drive library the installed apps
sync, because only a client from Submersion's Google Cloud project sees
that project's Drive app folder. Self-hosting is unchanged: the same
release zip still asks a self-hosted copy for a client id of its own.

## How it works

- **The build.** `build-all.yml`'s web job passes the repository variable
  `GOOGLE_WEB_CLIENT_ID` to `scripts/build_web.sh`, with
  `GOOGLE_WEB_CLIENT_ORIGINS=https://web.submersion.app`. The app uses the
  client only at that address, so one `Submersion-<tag>-Web.zip` serves
  both the site and self-hosters. The client goes in when the beta is
  built: promotion copies the beta's files and builds nothing.
- **The host.** GitHub Pages, from the `main` branch root of
  [submersion-app/web](https://github.com/submersion-app/web), with the
  custom domain `web.submersion.app`. Pages sends no custom headers, so
  Chrome runs the slower IndexedDB storage (see `web_hosting/HOSTING.md`);
  it also sends no opener policy, so Google's sign-in popup works.
- **The deploy.** `.github/workflows/deploy-web.yml` takes a stable tag,
  downloads that release's `Web.zip`, stages it with
  `scripts/web/stage_hosted_site.py` (the bundle check, `CNAME`,
  `.nojekyll`), and force-pushes it to `submersion-app/web` as a single
  commit over SSH with a deploy key. `promote.yml` calls it after every
  promotion, and `release.yml` for a stable tag pushed by hand.

## One-time setup

Do these in order. Steps 1 to 4 are the owner's: they need the Google
Cloud project, the domain's DNS and the repositories' settings.

1. **The Google web client, before the next beta is built.** In the
   [Google Cloud console](https://console.cloud.google.com/), in the
   project that holds the installed apps' OAuth clients: APIs & Services,
   Credentials, **Create credentials**, **OAuth client ID**, type **Web
   application**, with `https://web.submersion.app` under **Authorised
   JavaScript origins** (no redirect URI). Then set its id as a repository
   variable (a web client id is public, so not a secret):

   ```bash
   gh variable set GOOGLE_WEB_CLIENT_ID --repo submersion-app/submersion --body "<id>.apps.googleusercontent.com"
   ```

   Only betas built after this carry the client, and only their promotion
   gives the site Google Drive sign-in.

2. **The consent screen.** In the same project, OAuth consent screen:
   check it is **In production**, not Testing, so anyone can sign in, and
   that `submersion.app` is an authorised domain. The installed apps
   already sign in through this project, so it is most likely published
   already; Google may re-check the branding after the new origin is
   added.

3. **DNS.** At the domain's DNS host, a `CNAME` record for `web` pointing
   at `submersion-app.github.io`. Check it with
   `dig +short web.submersion.app CNAME`.

4. **The deploy key.** Generate a key pair, give the public half write
   access to the Pages repository, store the private half as this
   repository's secret, and delete both files:

   ```bash
   ssh-keygen -t ed25519 -N "" -C web-deploy -f web_deploy_key
   ```

   ```bash
   gh repo deploy-key add web_deploy_key.pub --repo submersion-app/web --allow-write --title "Deploy from submersion-app/submersion"
   ```

   ```bash
   gh secret set WEB_DEPLOY_KEY --repo submersion-app/submersion < web_deploy_key
   ```

   ```bash
   rm web_deploy_key web_deploy_key.pub
   ```

5. **HTTPS.** Once DNS resolves, in submersion-app/web, Settings, Pages:
   confirm the custom domain shows as verified and tick **Enforce HTTPS**
   when the certificate has been issued.

The Pages repository itself already exists, with Pages turned on from
`main` and the custom domain set.

## Before the setup is finished

- **No `WEB_DEPLOY_KEY`:** the deploy job writes a notice and succeeds
  without deploying. A promotion is never held up or reported as failed
  by the site's setup.
- **No Google client in the bundle** (a beta built before step 1): the
  bundle still deploys, with a warning in the run. Google Drive on the
  site then asks visitors for a client id until a release built with the
  client is deployed. The other stores work as usual.

## Deploying by hand

To redeploy a release, or deploy one that a promotion skipped:

```bash
gh workflow run deploy-web.yml --repo submersion-app/submersion -f tag=v1.8.4.9400
```

The run refuses a pre-release tag, and a release whose GitHub release has
no `Web.zip` (those before the web app, PR #4142).

**Rolling back** to an older release needs `force`:

```bash
gh workflow run deploy-web.yml --repo submersion-app/submersion -f tag=v1.8.4.9400 -f force=true
```

Without it the run refuses any release older than the one the site serves
(read from the site's `version.json`). The reason: every visitor's library
lives in their own browser on the one address, and the newer release has
already moved it to its schema. An older release cannot open a newer
schema (`DatabaseVersionMismatchException`), and a visitor has no way to
update past it. Force a rollback only to a release with the same schema
version; otherwise fix forward with a new release.
