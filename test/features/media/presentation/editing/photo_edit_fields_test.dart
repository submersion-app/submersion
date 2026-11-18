import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

final _at = DateTime.utc(2026, 11, 1);

MediaItem _item({int? pin, ColorAdjustment? color}) => MediaItem(
  id: 'm1',
  diveId: 'd1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026, 11, 1, 9, 2),
  createdAt: _at,
  updatedAt: _at,
  manualElapsedSeconds: pin,
  colorAdjustment: color,
  enrichment: MediaEnrichment(
    id: 'e1',
    mediaId: 'm1',
    diveId: 'd1',
    elapsedSeconds: pin ?? 120,
    depthMeters: 12.0,
    matchConfidence: pin == null
        ? MatchConfidence.interpolated
        : MatchConfidence.manual,
    createdAt: _at,
  ),
);

PhotoRecord _record({int? pin, int shift = 0, ColorAdjustment? color}) =>
    PhotoRecord(
      item: _item(pin: pin, color: color),
      species: const [
        SpeciesTagChip(
          speciesId: 'turtle',
          storedName: 'Turtle',
          category: SpeciesCategory.turtle,
          isBuiltIn: true,
        ),
      ],
      people: const [],
      diveShiftSeconds: shift,
    );

const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0.0),
  DiveProfilePoint(timestamp: 100, depth: 10.0),
  DiveProfilePoint(timestamp: 200, depth: 20.0),
  DiveProfilePoint(timestamp: 300, depth: 30.0),
];

void main() {
  test('each field reads and writes its value on PhotoRecord', () {
    final record = _record(pin: 50, shift: 10);
    const color = ColorAdjustment(warmth: 0.3);

    expect(photoPinField.read(record), 50);
    expect(photoPinField.read(photoPinField.write(record, 70)), 70);
    expect(photoDiveShiftField.read(record), 10);
    expect(photoDiveShiftField.read(photoDiveShiftField.write(record, 0)), 0);
    expect(photoColorField.read(photoColorField.write(record, color)), color);
    expect(photoSpeciesField.read(record), SpeciesTagEdits.none);
    expect(photoPeopleField.read(record), PersonTagEdits.none);
    final untagged = photoSpeciesField.write(
      record,
      SpeciesTagEdits.none.toggled(
        record.species.single,
        tagged: false,
        stored: record.species,
      ),
    );
    expect(untagged.species, isEmpty);
    // Every field owns one of the photo's change names.
    expect(photoPinField.cardId, photoTimeCardId);
    expect(photoDiveShiftField.cardId, photoTimeCardId);
    expect(photoColorField.cardId, photoColorCardId);
    expect(photoSpeciesField.cardId, photoSpeciesCardId);
    expect(photoPeopleField.cardId, photoPeopleCardId);
    expect(photoSiteCategoryField.cardId, photoDetailsCardId);
    expect(photoDisplaySizeField.cardId, photoDetailsCardId);
  });

  test('a colour reset over a stored neutral one is no change', () {
    // The repository stores a cleared adjustment as the neutral value.
    final session = EditSession<PhotoRecord>(
      _record(color: const ColorAdjustment()),
    );

    session.set(photoColorField, null);

    expect(session.isDirty, isFalse);
  });

  test('a shift chosen clears the pin and shows the shifted time', () {
    final session = EditSession<PhotoRecord>(_record(pin: 300));

    applyTimeChoice(
      session,
      const MediaTimeDiveShifted(60),
      automatic: (elapsedSeconds: 120, diveShiftSeconds: 0),
    );

    expect(session.valueOf(photoPinField), isNull);
    expect(session.valueOf(photoDiveShiftField), 60);
    expect(elapsedInSitting(session), 180);
  });

  test('a pin shows at once', () {
    final session = EditSession<PhotoRecord>(_record());

    applyTimeChoice(session, const MediaTimePinned(200));

    expect(session.valueOf(photoPinField), 200);
    expect(elapsedInSitting(session), 200);
  });

  test('Reset with no automatic time shows the stored enrichment', () {
    final session = EditSession<PhotoRecord>(_record(pin: 300));

    applyTimeChoice(session, const MediaTimeReset());

    expect(session.valueOf(photoPinField), isNull);
    expect(elapsedInSitting(session), isNull);
  });

  test('a shift removed puts the shift to zero', () {
    final session = EditSession<PhotoRecord>(_record(shift: 90));

    applyTimeChoice(
      session,
      const MediaTimeDiveShiftRemoved(),
      automatic: (elapsedSeconds: 210, diveShiftSeconds: 90),
    );

    expect(session.valueOf(photoDiveShiftField), 0);
    expect(elapsedInSitting(session), 120);
  });

  test('nothing changed: the stored enrichment stands', () {
    final session = EditSession<PhotoRecord>(_record());

    expect(elapsedInSitting(session), isNull);
    expect(photoShownItem(session, _profile), session.working.item);
  });

  test('photoShownItem: depth from the profile at the held time; '
      'isManual for a pin', () {
    final session = EditSession<PhotoRecord>(_record());

    applyTimeChoice(session, const MediaTimePinned(200));
    final shown = photoShownItem(session, _profile);

    expect(shown.manualElapsedSeconds, 200);
    expect(shown.enrichment?.elapsedSeconds, 200);
    expect(shown.enrichment?.depthMeters, closeTo(20.0, 0.01));
    expect(shown.enrichment?.isManual, isTrue);
  });

  test('photoShownItem for a shift: not manual', () {
    final session = EditSession<PhotoRecord>(_record());

    applyTimeChoice(
      session,
      const MediaTimeDiveShifted(80),
      automatic: (elapsedSeconds: 120, diveShiftSeconds: 0),
    );
    final shown = photoShownItem(session, _profile);

    expect(shown.enrichment?.elapsedSeconds, 200);
    expect(shown.enrichment?.isManual, isFalse);
  });

  test('a session rebased onto a stored tag added elsewhere keeps the held '
      'edits', () {
    final stored = _record();
    final session = EditSession<PhotoRecord>(stored);
    session.set(
      photoSpeciesField,
      SpeciesTagEdits.none.toggled(
        stored.species.single,
        tagged: false,
        stored: stored.species,
      ),
    );

    final synced = stored.copyWith(
      people: [
        MediaPersonChip(
          tag: MediaPersonTag(
            id: 't9',
            mediaId: 'm1',
            diverId: 'me',
            createdAt: _at,
            updatedAt: _at,
          ),
        ),
      ],
      species: [
        ...stored.species,
        const SpeciesTagChip(
          speciesId: 'shark',
          storedName: 'Shark',
          category: SpeciesCategory.fish,
          isBuiltIn: true,
        ),
      ],
    );
    session.rebase(synced);

    expect(session.isDirty, isTrue);
    expect(session.working.species.map((c) => c.speciesId), ['shark']);
    expect(session.working.people.single.tag.id, 't9');
  });

  test('a held relink is drawn as the file it found: its path, found, and '
      'not yet checked', () {
    final stored = _item().copyWith(
      sourceType: MediaSourceType.localFile,
      localPath: '/gone/m1.jpg',
      bookmarkRef: 'old-ref',
      isOrphaned: true,
      lastVerifiedAt: _at,
      contentSizeBytes: 100,
    );
    final session = EditSession<PhotoRecord>(
      PhotoRecord(item: stored, species: const [], people: const []),
    );
    addTearDown(session.dispose);
    session
      ..remember(
        photoRelinkProposalKey,
        RepairProposal(
          item: stored,
          confidence: RepairConfidence.exact,
          candidate: const RepairCandidate.file(
            path: '/found/m1.jpg',
            sizeBytes: 9,
            hash: 'h',
          ),
        ),
      )
      ..holdChange(photoRelinkKey, cardId: photoFileCardId, write: () async {});

    final drawn = withHeldRelink(session, stored);

    expect(drawn.localPath, '/found/m1.jpg');
    expect(drawn.bookmarkRef, isNull);
    expect(drawn.isOrphaned, isFalse);
    // The stored check was of the old file.
    expect(drawn.lastVerifiedAt, isNull);
    // A row with no hash takes the file's bytes as its own, so the repair
    // keeps its size, and the drawing shows what Save will write.
    expect(drawn.contentSizeBytes, 100);
  });

  test('a held relink to other bytes is drawn with their hash, as not yet '
      'backed up, and as linked on this device', () {
    final stored = _item().copyWith(
      sourceType: MediaSourceType.localFile,
      localPath: '/gone/m1.jpg',
      contentHash: 'OLD',
      remoteUploadedAt: _at,
      remoteThumbUploadedAt: _at,
      remoteCompressedUploadedAt: _at,
      originDeviceId: 'other-device',
    );
    final session = EditSession<PhotoRecord>(
      PhotoRecord(item: stored, species: const [], people: const []),
    );
    addTearDown(session.dispose);
    session
      ..remember(
        photoRelinkProposalKey,
        RepairProposal(
          item: stored,
          confidence: RepairConfidence.edited,
          candidate: const RepairCandidate.file(
            path: '/found/m1.jpg',
            sizeBytes: 9,
            hash: 'NEW',
          ),
        ),
      )
      ..holdChange(photoRelinkKey, cardId: photoFileCardId, write: () async {});

    final drawn = withHeldRelink(session, stored, thisDevice: 'this-device');

    expect(drawn.contentHash, 'NEW');
    expect(drawn.remoteUploadedAt, isNull);
    expect(drawn.remoteThumbUploadedAt, isNull);
    expect(drawn.remoteCompressedUploadedAt, isNull);
    expect(drawn.originDeviceId, 'this-device');
  });

  test('a held relink to the same bytes keeps what the store holds', () {
    final stored = _item().copyWith(
      sourceType: MediaSourceType.localFile,
      localPath: '/gone/m1.jpg',
      contentHash: 'SAME',
      remoteUploadedAt: _at,
    );
    final session = EditSession<PhotoRecord>(
      PhotoRecord(item: stored, species: const [], people: const []),
    );
    addTearDown(session.dispose);
    session
      ..remember(
        photoRelinkProposalKey,
        RepairProposal(
          item: stored,
          confidence: RepairConfidence.exact,
          candidate: const RepairCandidate.file(
            path: '/found/m1.jpg',
            sizeBytes: 9,
            hash: 'SAME',
          ),
        ),
      )
      ..holdChange(photoRelinkKey, cardId: photoFileCardId, write: () async {});

    final drawn = withHeldRelink(session, stored);

    expect(drawn.contentHash, 'SAME');
    expect(drawn.remoteUploadedAt, _at);
  });

  test('a held relink over a row with no hash keeps what the store holds, '
      'as the repair takes the bytes as the same', () {
    final stored = _item().copyWith(
      sourceType: MediaSourceType.localFile,
      localPath: '/gone/m1.jpg',
      contentHash: null,
      remoteUploadedAt: _at,
    );
    final session = EditSession<PhotoRecord>(
      PhotoRecord(item: stored, species: const [], people: const []),
    );
    addTearDown(session.dispose);
    session
      ..remember(
        photoRelinkProposalKey,
        RepairProposal(
          item: stored,
          confidence: RepairConfidence.exact,
          candidate: const RepairCandidate.file(
            path: '/found/m1.jpg',
            sizeBytes: 9,
            hash: 'H',
          ),
        ),
      )
      ..holdChange(photoRelinkKey, cardId: photoFileCardId, write: () async {});

    final drawn = withHeldRelink(session, stored);

    expect(drawn.contentHash, isNull);
    expect(drawn.remoteUploadedAt, _at);
  });
}
