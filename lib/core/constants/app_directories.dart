/// The folder under the platform documents directory that holds the app's
/// own persistent data: the database and its sidecars, pre-reset backups,
/// and the scanned-page copies written by the OCR import flow.
///
/// On Windows and Linux `getApplicationDocumentsDirectory()` is the user's
/// own Documents folder, so app-owned data written directly under it sits
/// among their personal files (issue #1645). Files the user asked for, such
/// as exports, deliberately land in the Documents root where they can find
/// them; everything the app keeps for itself goes under this name.
const String kAppDocumentsFolder = 'Submersion';
