import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Formats a resync can replay from a single stored file.
///
/// The import side stores a file only for these, and the resync side offers
/// the action only for these -- one constant so the two can never drift apart
/// (issue #478). CSV needs field-mapping state this feature does not store,
/// macdiveSqlite (and sqlite) are multi-file database imports with no single
/// file to re-parse, and every other unlisted format has no real parser.
const resyncableImportFormats = {
  ImportFormat.uddf,
  ImportFormat.macdiveXml,
  ImportFormat.subsurfaceXml,
  ImportFormat.danDl7,
  ImportFormat.fit,
  ImportFormat.shearwaterDb,
  ImportFormat.ratioXml,
};
