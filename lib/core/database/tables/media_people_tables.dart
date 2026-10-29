/// People tagged on photos and videos (issue #1745).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/media_tables.dart';

/// One person tagged on a photo or video (v326): a buddy, or the diver
/// themself ("Me"). Exactly one of [buddyId] and [diverId] is set.
///
/// The box marks where the person is, normalised 0 to 1 against the full
/// image; all four box columns are set or all are null (a tag without a
/// spot). [videoPositionMs] is set only for a face tag on a video, the
/// paused frame the box was drawn on, so one person can be tagged at several
/// moments of one video. Photos and videos share the table so "who is in
/// this media" is one query.
///
/// Unlike `media_species`, a row is edited after it is written (the box
/// moved or resized, the person changed), so it carries [updatedAt] and
/// resolves conflicts by its own clock.
class MediaPeople extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId =>
      text().references(Media, #id, onDelete: KeyAction.cascade)();
  TextColumn get buddyId =>
      text().nullable().references(Buddies, #id, onDelete: KeyAction.cascade)();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.cascade)();
  RealColumn get bboxX => real().nullable()();
  RealColumn get bboxY => real().nullable()();
  RealColumn get bboxWidth => real().nullable()();
  RealColumn get bboxHeight => real().nullable()();
  IntColumn get videoPositionMs => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// This tag's own clock, stamped when it is marked pending.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
