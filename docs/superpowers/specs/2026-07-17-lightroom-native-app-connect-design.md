# Lightroom Connect via OAuth Native App — Design

Date: 2026-07-17
Status: Approved pending user review
Amends: `docs/superpowers/specs/2026-07-11-lightroom-auto-linking-design.md` — the
auth/credential sections only. The acquisition-source architecture, scan, matching,
enrichment, and Media Store integration from that spec are unchanged.

## 1. Overview

The Lightroom connector currently authenticates as if it held an Adobe **Web App**
credential: `AdobeImsAuthManager` sends an optional client secret and *requires* a
refresh token, throwing when Adobe returns none. The Submersion project's Lightroom
Services credential is in fact an **OAuth Native App** credential — a public client
with no secret that, per Adobe's documentation, issues **no refresh token**. The two
are incompatible, which is the most likely reason the live connect never completed.

This design realigns the auth layer to the Native App credential and unifies two
credential sources behind one connect flow:

- **Embedded default** — Submersion bundles its own public Native App client ID.
  Because a client ID is public (not a secret), embedding is safe and needs no
  backend. It is entitled only for the credential owner and Console-allowlisted beta
  users until Adobe approves it; approval opens it to every user with zero setup.
- **BYO fallback** — a user supplies their own Native App client ID created in the
  Adobe Developer Console. Works today without approval, but requires the Console
  setup, so it is a power-user path.

This is the rollout the original spec already anticipated — "BYO now; if Adobe grants
a key it becomes the embedded default; BYO remains the fallback" — now achievable with
**no backend, no client secret, and no policy violation**, because the Native App
credential carries no secret.

### Decisions (settled during brainstorming, 2026-07-17)

| Question | Decision |
| --- | --- |
| Credential type | OAuth **Native App** (public client, PKCE, no secret). Confirmed in the Adobe Developer Console: Lightroom Services attaches to a Native App credential that exposes only a client ID. |
| Credential source | Unified: an **embedded** default client ID plus a **BYO** fallback. |
| Client secret | **Not required.** None is bundled or requested by the embedded flow. An optional `clientSecret` is retained in the auth manager, storage, and BYO UI for legacy Web App credentials, and is sent only if the user supplies one. |
| Refresh token | **Opportunistic.** Request `offline_access`; persist and use a refresh token if Adobe returns one; otherwise re-authenticate on access-token expiry. Never require it. |
| Redirect capture | **Embedded:** auto-capture via the credential's Adobe-generated custom scheme (`adobe+<hash>://adobeid/<clientId>`) using `flutter_web_auth_2`. **BYO:** copy-paste (the per-credential scheme cannot be registered at build time). |
| Poll model | **Manual scan + inline re-auth.** Retire the unattended periodic auto-poll (nothing can renew the token headless without a refresh token). |
| Approval | Needed only to open the **embedded** path to all users. BYO and Console beta users work without it. |

### Non-goals

- No Submersion-operated backend or token broker.
- No bundled client secret and none required (an optional `clientSecret` field is retained for BYO/legacy Web App credentials).
- No Web App or Single-Page App credential path.
- No Universal Links / App Links / associated-domains (custom scheme + loopback only).
- No change to scan, matching, enrichment, the Media Store pipeline, or the
  connected-accounts roster beyond what the auth change requires.
- Approval-submission materials (public walkthrough page, demo video, resubmission
  note) are tracked separately from this spec.

## 2. What changes

| Component | Change |
| --- | --- |
| `AdobeImsAuthManager` (`lib/core/services/lightroom/adobe_ims_auth_manager.dart`) | Make the client secret optional (no longer required; retained for BYO/legacy Web App credentials and sent only when provided). Take `clientId` and `redirectUri` as inputs, so embedded vs BYO differ only by argument. Stop requiring a refresh token — cache the access token with its expiry; persist a refresh token only if one is returned. Add a `needsReauth` signal when the access token has expired and no refresh path exists. |
| `LightroomAuthStore` / `LightroomAuthData` | Keep `clientSecret` as an optional field (no longer required). Store `clientId`, optional `clientSecret`, credential `source` (embedded/byo), `redirectUri`, optional `refreshToken`, catalog id, and account labels. |
| `LightroomConnectDialog` (`lib/features/settings/presentation/widgets/lightroom_connect_dialog.dart`) | Split capture by source. Embedded: `flutter_web_auth_2` in-app auth session (non-ephemeral), no paste. BYO: keep the copy-paste field. Reused as the wizard's sign-in step. |
| `lightroom_settings_page.dart` | Disconnected state offers a primary **Connect Lightroom** (embedded) and an **Advanced: use my own Adobe credentials** entry to the BYO wizard. |
| New `LightroomSetupWizard` | Focused BYO wizard (see §5). |
| New redirect-capture wrapper | Thin service over `flutter_web_auth_2`, injectable for tests. |
| `pubspec.yaml` | Add `flutter_web_auth_2`. |
| Native config | Register the **embedded** credential's custom scheme: iOS `CFBundleURLTypes`, Android `intent-filter` on `MainActivity`, macOS `CFBundleURLTypes`. Windows/Linux: see §6. |

## 3. Credential-source resolution

The app bundles two constants: the embedded client ID and its redirect URI (the
Adobe-generated `adobe+<hash>://adobeid/<clientId>` scheme). Connect resolves a source:

- **Embedded** (default): the bundled client ID + scheme; auto-capture.
- **BYO**: the user-entered client ID + the redirect URI the user copies from their own
  Console credential; copy-paste capture.

`AdobeImsAuthManager` is source-agnostic — it receives `clientId` + `redirectUri`. The
stored `source` drives which capture path the connect UI uses and how errors are worded.

## 4. Auth flow (Native App / PKCE)

**Authorize** — `beginAuthorization(clientId, redirectUri)` builds the IMS authorize
URL: `response_type=code`, PKCE `code_challenge` (S256),
`scope=openid,AdobeID,lr_partner_apis,lr_partner_rendition_apis,offline_access`, and the
resolved `redirect_uri`. No client-secret pairing.

**Capture**
- Embedded: `flutter_web_auth_2.authenticate(url, callbackUrlScheme: <embedded scheme>)`
  opens a non-ephemeral in-app auth session and returns the redirected URL;
  `extractAuthorizationCode` pulls the code.
- BYO: `url_launcher` opens the system browser; the user copies the code (or the full
  redirected URL) from the callback page and pastes it back; `extractAuthorizationCode`
  handles either form.

**Token exchange** — `completeAuthorization(code)` POSTs `grant_type=authorization_code`,
`client_id`, `code`, `code_verifier`, `redirect_uri` — **no `client_secret`**. Parse
`access_token`, `expires_in`, and `refresh_token` *if present*. Cache the access token
with an early-refresh expiry margin. Persist a refresh token only when returned.

**Token lifecycle** — `getAccessToken()`: return the cached token while valid; else, if
a refresh token exists, refresh (grant `refresh_token`, no secret); else raise
`needsReauth`. There is no silent path when no refresh token exists.

**Re-auth** — scan actions and the connector tile surface `needsReauth`. Reconnecting
runs the same authorize flow; with the Adobe IMS session persisted (non-ephemeral
session on the embedded path), this is frequently a silent redirect rather than a fresh
password entry.

**Disconnect** — clear the stored blob and cached access token; drop the cached
per-account manager.

## 5. BYO setup wizard

A focused `LightroomSetupWizard` at `/settings/lightroom/setup`, launched from the
disconnected settings state:

1. **What you'll need** — one-time, ~3 minutes; a Lightroom **cloud** account (see §9);
   an "I already have a client ID" shortcut to step 3.
2. **Create the integration** — an "Open Adobe Developer Console" button; instruction to
   create a project, add **Lightroom Services**, and create an **OAuth Native App**
   credential; the required scopes shown with a Copy button, sourced from the
   auth-manager constant so the instructions cannot drift from the actual request.
3. **Enter credentials** — the **client ID** and the credential's **redirect URI** (both
   copied from the user's Console; no secret), with non-empty validation.
4. **Sign in** — runs the authorize flow (BYO copy-paste capture),
   `completeAuthorization`, fetches account + catalog, creates/updates the connected
   account, shows success.

## 6. Platform redirect handling

The embedded custom scheme is known at build time and registered once:

- **iOS / Android / macOS** — custom-scheme capture via `flutter_web_auth_2`
  (`ASWebAuthenticationSession` / Custom Tabs). Clean, no paste.
- **Windows / Linux** — `flutter_web_auth_2` desktop capture uses an `http://localhost`
  loopback listener, which needs a loopback redirect URI rather than the custom scheme.
  Resolution, in priority order, settled at plan time: (a) if a Native App credential can
  carry an additional `http://127.0.0.1` redirect URI, use loopback capture on desktop;
  (b) otherwise register the custom scheme at the OS level (Windows registry / Linux
  `.desktop` handler) with single-instance routing; (c) otherwise fall back to
  copy-paste on Windows/Linux. Copy-paste is always the guaranteed fallback.

BYO always uses copy-paste (its per-credential scheme cannot be registered at build
time).

## 7. Product model / polling

Without a guaranteed refresh token, unattended polling cannot renew credentials.
Therefore:

- **Retire the unattended periodic auto-poll.** Scanning is user-initiated
  (dive / trip / all).
- If the access token is expired and cannot refresh, a scan action first prompts an
  inline reconnect, then proceeds.
- The **startup auto-poll trigger** runs only when a valid token already exists; it never
  launches an interactive prompt at startup. When re-auth is required it no-ops and the
  connector tile shows `needsReauth`.
- The connected-accounts roster surfaces `needsReauth` as the account status.

## 8. Entitlement & error handling

- **Unentitled account** (embedded credential, pre-approval, a non-owner / non-beta Adobe
  account): Adobe refuses authorization or the API returns an entitlement error. Show a
  specific message — the embedded connection is pending Adobe approval; offer the
  **Advanced (BYO)** path or waiting for approval. This is the expected pre-approval
  state for anyone but the owner and allowlisted beta users.
- **BYO misconfiguration** (bad client ID, wrong redirect URI, missing Lightroom
  entitlement): surface Adobe's error verbatim plus a link back to the wizard.
- **Token expired, no refresh token**: `needsReauth`; inline reconnect. No data is
  deleted; display continues via the Media Store.
- **Rate limits / transient network**: unchanged from the existing scan retry/backoff.

## 9. Prerequisite (both sources)

The photos must live in **Lightroom's cloud** — Lightroom (CC), or Lightroom Classic
with cloud sync enabled. A purely-local Classic catalog is not reachable by the API. The
connect UI states this so a user does not connect and find an empty catalog.

## 10. Testing

- `AdobeImsAuthManager`: connect with **no** client secret; **no** refresh token returned
  → success, access token cached, no throw (guards the current regression); refresh token
  returned → persisted and used; access token expired with no refresh token →
  `needsReauth`; opportunistic rotation when a rotated refresh token is returned.
- Redirect capture: `flutter_web_auth_2` wrapper mocked — embedded path returns a code;
  BYO copy-paste path via `extractAuthorizationCode` (raw-code and full-URL forms).
- Wizard: step navigation; the "already have a client ID" shortcut; scopes Copy value
  asserts equality against the constant; client ID + redirect URI required.
- Source resolution: embedded vs BYO selection drives the correct capture path and error
  wording.
- Reuse the verbatim-Adobe-error dialog test; keep the `tester.runAsync`
  drift/fakeAsync guard.

## 11. Localization

New and changed strings into `app_en.arb` and all ten other locales; unit-bearing values
continue to respect diver unit settings.

## 12. Migration

Existing stored Lightroom connections (if any) assume Web App semantics and lack a usable
refresh token; on upgrade, treat them as `needsReauth` and reconnect through the new flow.
Because the live connect never completed under the old mismatch, there are likely no real
connections to migrate; risk is low.

## 13. Risks & open items

- **Windows/Linux embedded capture** (§6) — resolution order specified; copy-paste is the
  guaranteed fallback. Verify at plan time whether a Native App credential can carry a
  loopback redirect URI.
- **`offline_access` on Native App** — Adobe's docs say no refresh token is issued; the
  opportunistic handling degrades gracefully whether or not one appears.
- **Approval dependency** — the embedded path is owner/beta-only until Adobe approves;
  BYO and beta users bridge the gap. See the separate approval playbook.
- **Pre-approval entitlement UX** — the unentitled-account message (§8) must be clear so
  beta testers and early users are not confused by refusals.
- **Embedded credential identity** — the credential to embed is the same project
  currently marked "Rejected"; resubmission is part of the approval track, not this spec.
