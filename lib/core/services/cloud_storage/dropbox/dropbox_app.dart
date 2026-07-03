/// Dropbox app key for Submersion (Dropbox developer console, "App folder"
/// access). Public by design: the PKCE flow has no client secret, so this
/// key is not sensitive and lives in source on purpose.
///
/// Empty until the Dropbox app is registered; the connect flow reports
/// "not configured in this build" until it is filled in. Registration
/// runbook: docs/superpowers/specs/2026-07-02-dropbox-sync-design.md.
const String dropboxAppKey = '';
