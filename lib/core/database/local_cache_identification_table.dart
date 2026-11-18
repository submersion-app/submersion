import 'package:drift/drift.dart';

/// The embedding of each marine life crop (issue #4668): the numbers a crop
/// is named from, so a model pack that changes only its names or bars, or a
/// photo that gains a location, can be named again without the photo or the
/// model.
///
/// Local-only by construction: it can be worked out again by analysing the
/// photo, so it carries no HLC, is never synced and is never backed up.
class IdentificationEmbeddings extends Table {
  @override
  String get tableName => 'identification_embeddings';

  /// The identification in the main database this crop belongs to.
  TextColumn get identificationId => text()();

  /// The embedding model that produced it. A different model's numbers are
  /// meaningless to another, so a read asks for the one installed.
  TextColumn get classifierId => text()();

  /// Little-endian 16-bit floats.
  BlobColumn get embedding => blob()();

  @override
  Set<Column> get primaryKey => {identificationId};
}

/// The table as [IdentificationEmbeddings] declares it, for the open
/// backstop that heals a database a colliding branch stamped at v25 first.
/// Keep the columns in step with the class.
const String kCreateIdentificationEmbeddingsSql = '''
  CREATE TABLE IF NOT EXISTS identification_embeddings (
    identification_id TEXT NOT NULL,
    classifier_id TEXT NOT NULL,
    embedding BLOB NOT NULL,
    PRIMARY KEY (identification_id)
  )
''';
