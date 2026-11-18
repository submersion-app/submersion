/// What the on-device model found on each photo, and what the diver made of
/// it (issue #4668).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

/// That a piece of media was analysed for marine life, with which models,
/// and against which place. One row per media item, written even when
/// nothing was found, so the same photo is not analysed twice.
///
/// Never synced (no hlc column): what was found depends on this device's
/// model pack, and the crops it refers to live only on this device. The
/// media id is deliberately not a reference: a delete held for undo removes
/// the media row and an undo puts it back, and a cascade would lose the
/// diver's decisions in between.
@DataClassName('MediaIdentificationRunRow')
class MediaIdentificationRuns extends Table {
  TextColumn get mediaId => text()();

  /// The model pack that analysed or last named this media.
  TextColumn get packVersion => text()();

  /// The detector and embedding model that analysed it. A pack that changes
  /// either one means analysing again; one that changes neither means only
  /// naming the stored crops again.
  TextColumn get detectorId => text()();
  TextColumn get classifierId => text()();

  /// The region grid cell naming used, or null when the media had no
  /// location.
  IntColumn get locationCell => integer().nullable()();

  /// Epoch milliseconds.
  IntColumn get analysedAt => integer()();

  /// The analysed image's size after orientation; boxes are relative to it.
  IntColumn get imageWidth => integer()();
  IntColumn get imageHeight => integer()();

  /// How many identifications were stored, possibly zero.
  IntColumn get detectionCount => integer()();

  /// Video only (issue #4675): how far the scan has got, in milliseconds
  /// from the start. Null for a photo. The scan is complete when it reaches
  /// video_duration_ms.
  IntColumn get scannedMs => integer().nullable()();

  /// Video only: the video's length in milliseconds, as the engine read
  /// it. Null for a photo.
  IntColumn get videoDurationMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {mediaId};
}

/// One animal the model found on a piece of media, with the species it
/// could be and what the diver decided. Never synced, for the same reasons
/// as [MediaIdentificationRuns].
@DataClassName('MediaIdentificationRow')
class MediaIdentifications extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId => text()();

  /// Where the animal is, normalised 0 to 1 against the analysed image.
  RealColumn get boxX => real()();
  RealColumn get boxY => real()();
  RealColumn get boxWidth => real()();
  RealColumn get boxHeight => real()();

  /// The box's size in the analysed image's pixels.
  IntColumn get boxPixelWidth => integer()();
  IntColumn get boxPixelHeight => integer()();

  RealColumn get detectorScore => real()();

  /// The best share over every candidate, before place is considered.
  RealColumn get openScore => real()();

  /// Ranked candidates as JSON, each with its GBIF key, scientific and
  /// common names, category, catalogue id when it has one, and score.
  /// Names are kept so a suggestion still shows after the model is removed.
  TextColumn get candidatesJson => text()();

  /// Whether candidates were limited to species recorded near the media.
  BoolColumn get locationLimited => boolean()();

  /// Whether it passed the naming bars when last named.
  BoolColumn get suggestable => boolean()();

  /// undecided, accepted or rejected.
  TextColumn get decision => text()();

  /// The species tagged, once accepted.
  TextColumn get decidedSpeciesId => text().nullable()();

  /// Epoch milliseconds.
  IntColumn get decidedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  /// Video only (issue #4675), where one row is one animal followed
  /// through the video: when it was first seen, in milliseconds from the
  /// start. Null for a photo.
  IntColumn get startMs => integer().nullable()();

  /// Video only: when the animal was last seen, in milliseconds from the
  /// start.
  IntColumn get endMs => integer().nullable()();

  /// Video only: the moment, in milliseconds from the start, whose box,
  /// crop and pixel size the box columns hold.
  IntColumn get bestMs => integer().nullable()();

  /// Video only: the box at each sample, packed (track_path_codec.dart).
  BlobColumn get trackPath => blob().nullable()();

  /// The species the diver gave this animal from the frame (a dot or a
  /// pill), held until the tag is written. It wins over the name rules.
  TextColumn get claimedSpeciesId => text().nullable()();

  /// Whether it passed the confident bar when it was last named. Stored so
  /// the labels over a video keep working after the model is removed.
  BoolColumn get confident => boolean().withDefault(const Constant(false))();

  /// Whether its open score passed the floor when it was last named: it
  /// looks like something in particular, not a hand or open water.
  BoolColumn get specific => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
