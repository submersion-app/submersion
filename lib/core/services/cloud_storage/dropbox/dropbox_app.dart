/// Dropbox app key for Submersion (Dropbox developer console, "App folder"
/// access). Public by design: the PKCE flow has no client secret, so this
/// key is not sensitive and lives in source on purpose.
///
/// The settings tile is gated on this being non-empty
/// (dropboxConfiguredProvider); registration runbook:
/// docs/superpowers/specs/2026-07-02-dropbox-sync-design.md.
const String dropboxAppKey = 'ut1wjdolx47063k';
