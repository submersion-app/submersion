/// Whether a site's page offers unlock-to-edit (issue #4527, phase 2).
///
/// Off until the site page has every card and the last phase 2 plan
/// switches it on and deletes the site edit form, so no release has two
/// ways to edit a site. Turned on for a build with
/// `--dart-define=UNLOCK_SITE_EDITING=true`.
const bool kUnlockSiteEditing = bool.fromEnvironment('UNLOCK_SITE_EDITING');
