/// Whether record pages offer unlock-to-edit (issue #4527).
///
/// Off unless the app is built with `--dart-define=UNLOCK_EDITING=true`.
/// The pattern is being built card by card; until a page has every card,
/// the switch keeps it out of released builds so no release has two ways to
/// edit the same record.
const bool kUnlockEditing = bool.fromEnvironment('UNLOCK_EDITING');
