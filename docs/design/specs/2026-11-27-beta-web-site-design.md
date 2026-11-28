# A beta web site (issue #4481)

## Intent

A tester runs the Android and Windows betas and asks for a beta of the web
app too. `https://web.submersion.app` serves stable releases only (hosted
site spec, `2026-11-03-hosted-web-app-design.md`, decision 3 and its
non-goal "A beta or preview site"). This change reverses that non-goal at
the owner's request.

The reason it matters: a beta build writes sync data above stable's schema
floor (#2619), so the stable web app holds every beta peer and a beta tester
cannot open their synced library in a browser. A beta web site, built from
the same commit as the beta apps, syncs with them.

Success:

- Every published beta reaches `https://beta.web.submersion.app` with no
  manual step, serving that beta's own `Web.zip` byte for byte (plus
  `CNAME` and `.nojekyll`).
- Google Drive signs in there with Submersion's client, as on the stable
  site.
- The stable site's About settings offer the beta site, the beta site's
  About settings offer the stable site, and the beta site's version reads
  "(Beta)".

## Decisions

| # | Question | Decision |
| --- | --- | --- |
| 1 | Address | `https://beta.web.submersion.app`, its own origin. A browser keeps storage per origin; a path such as `web.submersion.app/beta` would share the stable site's database, and one beta visit would upgrade it past what stable opens (the #1568 lockout, on the web). Each site keeps its own library and reaches shared data through sync (builder's proposal, accepted) |
| 2 | Host | GitHub Pages from the `main` branch root of a new public repository, `submersion-app/web-beta`, with the custom domain and HTTPS enforced. Pages allows one custom domain per repository, so the stable repository cannot serve both |
| 3 | When it updates | After every beta publish, from the `beta-builds` release `beta.yml` just created. A `workflow_dispatch` run can redeploy or roll back, as on the stable site |
| 4 | How the deploy is built | One workflow: `deploy-web.yml` gains a `site` input (`stable` or `beta`) that picks the source release repository, the Pages repository and the domain (owner's choice, over a second copied workflow). The stable path behaves exactly as today |
| 5 | How the app knows which site it is on | By the page's origin, compared with two constants (owner's choice, over a marker file written at deploy time). Promotion re-hosts the beta's files, so nothing fixed at build time can say "beta"; the origin is the one thing that differs at runtime |
| 6 | What the app shows | Owner's choice, "site plus in-app badge", as mocked up: on the stable site, About gets a **Try the beta web app** row; on the beta site, a **Use the stable web app** row and the version line reads "Version x (Beta)" in Settings and in the About Submersion dialog. Each row opens the other site in a new tab. A self-hosted copy matches neither origin and shows nothing new |
| 7 | Google client | `GOOGLE_WEB_CLIENT_ORIGINS` in `build-all.yml` becomes `https://web.submersion.app,https://beta.web.submersion.app`. The app already treats it as a comma-separated list. Owner adds the beta origin to the OAuth client's authorised JavaScript origins |
| 8 | Deploy token | The existing `WEB_DEPLOY_TOKEN` is edited to cover `submersion-app/web-beta` as well (builder's proposal, accepted). No second secret |
| 9 | Who creates the Pages repository | The builder, with `gh`, as for the stable site. The owner does DNS, the Google origin, the token's repository list and Enforce HTTPS |
| 10 | Rollout order | The beta site's setup is finished before this change merges (owner's choice, over a repository-variable switch). The builder creates `submersion-app/web-beta` with a README on `main` at the start of the work, so Pages publishes and the certificate can be issued; the owner does the four steps below while the PR is in review. No switch code: the deploy keeps today's single "token set" check, and the About rows ship unconditionally |
| 11 | How the app spells the sites (builder's call) | As host names (`web.submersion.app`, `beta.web.submersion.app`) joined to `https://` at runtime, never as full `https://` literals. `stage_hosted_site.py`'s Google-origin warning looks for `https://<domain>` as a plain substring of `main.dart.js` and relies on nothing but the `GOOGLE_WEB_CLIENT_ORIGINS` define spelling it; a full literal in `lib/` would let a bundle built without the beta origin pass the check. A guard test keeps `https://web.submersion.app` and `https://beta.web.submersion.app` out of `lib/` |

## Approaches considered

**Deploy pipeline.**

- *Chosen: one workflow with a `site` input.* The bundle check, the
  newer-only guard and the token-as-header push stay in one place, so a fix
  to one site's deploy fixes both.
- *A copied `deploy-web-beta.yml`.* Easier to read alone, but roughly 150
  duplicated lines that drift the first time one copy is fixed.
- *A folder or branch of `submersion-app/web`.* Ruled out: one custom
  domain per Pages repository, and a folder shares the stable site's
  storage.

**Detecting the beta site.**

- *Chosen: compare the page origin with constants.* Synchronous, no
  network read, testable as a pure function like
  `GoogleDriveClientConfig.builtInWebClientIdFor`.
- *A `site.json` marker written by the staging script.* Survives an
  address change without a release, but adds a fetch before About renders
  and another file the deploy must get right.

## How it works

### The deploy (`deploy-web.yml`)

New input `site`, `stable` (default) or `beta`, on both `workflow_call`
and `workflow_dispatch`. A first step maps it:

| | stable | beta |
| --- | --- | --- |
| Release repository | `submersion-app/submersion` | `submersion-app/beta-builds` |
| Pages repository | `submersion-app/web` | `submersion-app/web-beta` |
| Domain | `web.submersion.app` | `beta.web.submersion.app` |
| `sqlite3_wasm.lock` read from | the tag in this repository | the `sourceSha` in the release's `metadata.json`, fetched from this repository (beta tags exist only in `beta-builds`) |

Everything else is shared: refuse a tag with a `-` suffix, refuse a tag
with no release, download `Submersion-<tag>-Web.zip`, stage with
`scripts/web/stage_hosted_site.py` (bundle check, `CNAME`, `.nojekyll`,
client warnings for the site's own origin), refuse an older bundle unless
`force`, publish one orphan commit by force-push.

Concurrency becomes one group per site (`deploy-web-<site>`), still never
cancelled, so a beta deploy never queues behind a stable one.

### The caller (`beta.yml`)

A `deploy-web` job after `publish-beta`, `uses: ./.github/workflows/deploy-web.yml`
with the beta tag and `site: beta`, passing `WEB_DEPLOY_TOKEN`. It runs only
when `publish-beta` succeeded, so a build-only dispatch (`skip-publish`)
deploys nothing. It joins the `alert` job's `needs`, so a failed beta web
deploy raises the beta failure alert like any other publish lane. No store
lane depends on it.

### The build (`build-all.yml`)

`GOOGLE_WEB_CLIENT_ORIGINS` lists both addresses. Because promotion
re-hosts the beta's files, the stable site's bundle carries the beta
origin as well; harmless, since the app uses the client only at the
address the page is actually served from.

### The app

- A small domain file, next to `beta_program_links.dart`, holds the two
  site host names (decision 11) and a pure rule,
  `hostedWebSiteFor(pageOrigin)`, returning stable, beta, or none
  (normalised like the Google client check: case, trailing slash).
- **Version badge.** `watchAboutVersionLabel` badges the version when the
  desktop updater is on the beta channel (today) *or* the page is the beta
  site. Reuses `settings_updates_channelBadgeBeta`.
- **Rows.** The About card shows, on the web only:
  - stable site: icon `science_outlined`, title "Try the beta web app",
    subtitle naming the beta address and saying it keeps its own library,
    reached through sync;
  - beta site: a back icon, title "Use the stable web app", subtitle naming
    the stable address and saying its library is separate.
  Each opens the other site in a new browser tab. The existing store
  "Join the Beta" row is unchanged and never shows on the web.
- New strings go through the project's l10n workflow in every locale.

### Docs

- `docs/user/web-app.md`: a "Beta web app" section: the address, that it
  updates with every beta, that its library is separate and fills through
  sync, and the beta/stable sync floor (a stable device holds beta peers).
  The S3 and WebDAV CORS instructions say to list the beta address as an
  allowed origin too when syncing from it.
- `docs/developer/web-site-setup.md`: the beta site's one-time setup and
  the manual redeploy with `site=beta`.
- README beta section: the beta web address beside TestFlight and Play.
- The hosted-site spec's non-goal gets a note pointing here.

## One-time setup (owner, outside the repository)

1. Google Cloud: add `https://beta.web.submersion.app` to the web client's
   authorised JavaScript origins.
2. DNS: a `CNAME` for `beta.web` pointing at `submersion-app.github.io`.
3. Edit the `WEB_DEPLOY_TOKEN` fine-grained token to add
   `submersion-app/web-beta` (Contents read and write); re-approve if the
   organisation asks.
4. In `submersion-app/web-beta` Settings, Pages: tick **Enforce HTTPS**
   once the certificate is issued (the README the builder pushes makes the
   site live before the first deploy).

All four are done before this change merges (decision 10). With the token
left uncovered, every beta deploy would fail and raise the beta alert;
with the site not live, the next promotion would show stable users a row
pointing at nothing.

The builder creates `submersion-app/web-beta` (public, a README on `main`)
and turns Pages on from `main` with the custom domain.

## Goals

- A published beta reaches the beta site with no manual step.
- The stable site's deploy is unchanged in behaviour.
- A tester can tell which site they are on and move between them from
  About.

## Non-goals

- Carrying a library from one site to the other other than by sync.
- A banner, colour or title change on the beta site outside About.
- Cross-origin isolation headers (same as the stable site).
- Links from the `submersion.app` website.

## Anti-goals

- A beta site that shares storage with the stable site.
- A beta web bundle that differs from the beta that shipped to the stores.
- A beta publish, or a store lane, held up or failed by the web site's
  setup (the deploy still skips with a notice while the token is unset).
- A self-hosted copy that shows a link to Submersion's sites.

## Left to the builder

- Exact step layout of the `site` mapping in `deploy-web.yml` and how
  `sourceSha` is read.
- Icon for the "Use the stable web app" row, and the strings' final
  wording within the meaning above.
- Test layout: the origin rule and row rule as pure-function tables, a
  widget test for the About rows and badge, and the staging script tests
  if its interface changes.
