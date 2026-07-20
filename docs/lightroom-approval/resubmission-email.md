# Resubmission email — Adobe Creative Cloud Integrations Review

**To:** CCIntegrationsReview@adobe.com
**Subject:** Revised submission — Submersion Lightroom Services integration

> Fill in the bracketed values before sending. Send only after (1) the Native App
> auth fix has landed so the connect works, (2) the demo video is recorded, and
> (3) the walkthrough page is live at https://submersion.app/lightroom and set as
> the submission's App Website.

---

Hello,

Thank you for the review notes on Submersion. We have addressed each point and are resubmitting.

**First, to disambiguate the integration type:** Submersion integrates with the **Adobe Lightroom Services API** (Creative Cloud) using Adobe IMS OAuth 2.0 with an **OAuth Native App** credential and standard three-legged, user-consented authorization. It does **not** use the Adobe Express Embed SDK — so the Creative Cloud Developer guidelines are the applicable set, not the Express SDK checklist.

**Why there was no API to find at the previous URL, and how it's fixed:** Submersion is a native desktop and mobile application (macOS, Windows, Linux, iOS, Android), not a web app, so there is no hosted web page a reviewer can click through to exercise the integration. Our previous App Website pointed at our general homepage, which did not document the Lightroom integration. We have published a dedicated end-to-end walkthrough and updated the submission's **App Website** to point to it:

- **Walkthrough (complete end-to-end workflow):** https://submersion.app/lightroom
- **Demonstration video:** [VIDEO URL]

Addressing each item in your notes:

1. **"Unable to locate the Lightroom API at the provided URL."** The App Website now points to the walkthrough page above, which documents the integration, the OAuth flow, the scopes used, and the Lightroom Services endpoints called.
2. **"Clearly outline the steps required to access and use it."** The walkthrough lists the exact user steps (Settings → Photos & Media → Connect Lightroom → sign in with Adobe → done) and the technical details: credential type, scopes, and API endpoints.
3. **"Include a demonstrative video."** The video above shows the full workflow in the app: connecting, scanning a dive trip, confirming a photo match, viewing the photo on the dive, and opening the original in Lightroom.

**Integration details for your reference:**

- Credential: OAuth Native App (public client, PKCE, no client secret). Client ID: `[CLIENT ID]`.
- Scopes: `openid`, `AdobeID`, `lr_partner_apis`, `lr_partner_rendition_apis`, `offline_access`.
- Access is **read-only** and per-user (each user consents with their own Adobe account); Submersion runs no server that stores Adobe tokens or user photos.
- Endpoints: `lr.adobe.io` — `/v2/account`, `/v2/catalog`, `/v2/catalogs/{id}/albums`, `/v2/catalogs/{id}/assets`, and asset renditions.

Please let us know if any further material would help the review. Thank you for your time.

Best regards,
Eric Griffin
Submersion
[SUPPORT EMAIL]
