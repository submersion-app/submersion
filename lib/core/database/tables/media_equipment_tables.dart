/// Gear items linked to photos and videos (issue #5046).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/media_tables.dart';

/// One gear item shown in one photo or video (v388): "this photo shows my
/// drysuit". The photo stays an ordinary photo; this is not
/// `media.equipment_id`, which makes a row a gear photo.
///
/// Surrogate uuid primary key, like [MediaTags], so a pair unlinked and
/// linked again never collides with its predecessor's tombstone (#347).
/// Rows are created and deleted, never edited, so there is no updated_at.
class MediaEquipment extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  /// This link's own clock, stamped when it is marked pending.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {mediaId, equipmentId},
  ];
}
