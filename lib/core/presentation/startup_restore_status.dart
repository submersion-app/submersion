/// How far an in-place restore offered by a startup screen has got.
///
/// Shared by the terminal failure screen and the schema-mismatch screen, both
/// of which can offer a backup and both of which run before the router, the
/// database and any state management exist.
enum StartupRestoreStatus { idle, running, failed }
