/// The folder under the platform documents directory that holds everything
/// the app owns there: the database and its sidecars, pre-reset backups,
/// and the scanned-page copies written by the OCR import flow.
///
/// On Windows and Linux `getApplicationDocumentsDirectory()` is the user's
/// own Documents folder, so a file written directly under it sits among
/// their personal files (issue #1645). Every documents-directory path the
/// app builds must go through this one name.
const String kAppDocumentsFolder = 'Submersion';
