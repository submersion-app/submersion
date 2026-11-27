import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/auto_applier.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

import '../../../helpers/test_database.dart';
import '../../media/data/repositories/species_photo_fixtures.dart';
import 'identification_fixtures.dart';

/// Opens another logbook while it resolves a species.
class _SwitchingAcceptor extends SuggestionAcceptor {
  _SwitchingAcceptor({required super.species, required this.onResolve});

  final void Function() onResolve;

  @override
  Future<({domain.Species species, bool created})> resolveWithOrigin(
    PackCandidate candidate, {
    bool Function()? mayCreate,
  }) {
    onResolve();
    return super.resolveWithOrigin(candidate, mayCreate: mayCreate);
  }
}

/// Tagging confident matches with no tap (issue #4727).
void main() {
  late AppDatabase db;
  late MediaIdentificationRepository identifications;
  late MediaSpeciesRepository tags;
  late SpeciesRepository species;
  var autoApply = true;
  var generation = 0;
  var packAllows = true;
  final changeLog = ChangeLogRepository();

  /// The service's reconcile, without a naming level: decisions in step
  /// with the tags from the stored flags.
  Future<void> reconcileStored(String mediaId) async {
    final changed = reconcileDecisions(
      await identifications.forMedia(mediaId),
      await identifications.taggedSpecies(mediaId),
      now: DateTime.utc(2026, 11, 18),
    );
    if (changed.isNotEmpty) await identifications.updateDecisions(changed);
  }

  AutoApplier applier({
    Future<void> Function(String mediaId)? reconcile,
    SuggestionAcceptor? acceptor,
    String? deviceId,
  }) => AutoApplier(
    identifications: identifications,
    acceptor: acceptor ?? SuggestionAcceptor(species: species),
    tagging: SpeciesTaggingService(
      tags: tags,
      media: MediaRepository(),
      species: species,
    ),
    enabled: () => autoApply,
    timing: () => SightingTiming.onConfirm,
    reconcile: reconcile ?? reconcileStored,
    databaseGeneration: () => generation,
    packAllows: () => packAllows,
    deviceId: () async => deviceId,
  );

  Future<void> store(String mediaId, {bool confident = true}) =>
      identifications.storeRun(
        run(mediaId: mediaId),
        insert: [
          identification(
            'i-$mediaId',
            mediaId: mediaId,
          ).copyWith(confident: confident),
        ],
        deleteIds: const [],
      );

  setUp(() async {
    db = await setUpTestDatabase();
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    autoApply = true;
    generation = 0;
    packAllows = true;
    identifications = MediaIdentificationRepository();
    tags = MediaSpeciesRepository();
    species = SpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('tags a confident species, unconfirmed, and accepts the crop', () async {
    await insertTestSpecies(
      id: 'sp_queen_parrotfish',
      name: 'Queen Parrotfish',
    );
    await store('p1');

    expect(
      await applier().applyInScope('p1', isVideo: false, generation: 0),
      1,
    );

    final tag = await tags.findTag('p1', 'sp_queen_parrotfish');
    expect(tag!.unconfirmed, isTrue);
    expect(tag.createdSpecies, isFalse);
    final row = (await identifications.forMedia('p1')).single;
    expect(row.decision, IdentificationDecision.accepted);
  });

  test(
    'only the device that made the run applies from it (issue #4876)',
    () async {
      await insertTestSpecies(
        id: 'sp_queen_parrotfish',
        name: 'Queen Parrotfish',
      );
      await identifications.storeRun(
        run(mediaId: 'p1').copyWith(analysedBy: () => 'laptop'),
        insert: [
          identification('i-p1', mediaId: 'p1').copyWith(confident: true),
        ],
        deleteIds: const [],
      );

      expect(
        await applier(
          deviceId: 'phone',
        ).applyInScope('p1', isVideo: false, generation: 0),
        0,
      );
      expect(await tags.findTag('p1', 'sp_queen_parrotfish'), isNull);
      expect(
        await applier(
          deviceId: 'laptop',
        ).applyInScope('p1', isVideo: false, generation: 0),
        1,
      );
    },
  );

  test('a leftover of a run that lost a sync race is hidden, so it is not '
      'applied (issue #4876)', () async {
    await insertTestSpecies(
      id: 'sp_queen_parrotfish',
      name: 'Queen Parrotfish',
    );
    await identifications.storeRun(
      run(
        mediaId: 'p1',
      ).copyWith(analysedBy: () => 'laptop', runId: () => 'r-laptop'),
      insert: [
        identification(
          'i-mac',
          mediaId: 'p1',
        ).copyWith(confident: true, runId: () => 'r-mac'),
      ],
      deleteIds: const [],
    );

    expect(
      await applier(
        deviceId: 'laptop',
      ).applyInScope('p1', isVideo: false, generation: 0),
      0,
    );
    expect(await tags.findTag('p1', 'sp_queen_parrotfish'), isNull);
  });

  test('reconciles through the service, which follows the naming level, '
      'and only when it tagged something', () async {
    await insertTestSpecies(
      id: 'sp_queen_parrotfish',
      name: 'Queen Parrotfish',
    );
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await store('p1');
    await store('p2', confident: false);
    final reconciled = <String>[];
    final spied = applier(reconcile: (id) async => reconciled.add(id));

    await spied.applyInScope('p1', isVideo: false, generation: 0);
    await spied.applyInScope('p2', isVideo: false, generation: 0);

    expect(reconciled, ['p1']);
  });

  test('records the species it had to create', () async {
    await store('p1');

    await applier().applyInScope('p1', isVideo: false, generation: 0);

    final created = await species.findSpeciesByScientificName('Scarus vetula');
    final tag = await tags.findTag('p1', created!.id);
    expect(tag!.createdSpecies, isTrue);
  });

  test('nothing when it is not confident', () async {
    await store('p1', confident: false);
    expect(
      await applier().applyInScope('p1', isVideo: false, generation: 0),
      0,
    );
    expect(await tags.getTagsForMedia('p1'), isEmpty);
  });

  test('nothing while the installed pack can never be confident, as the '
      'setting shows', () async {
    await store('p1');
    packAllows = false;

    expect(
      await applier().applyInScope('p1', isVideo: false, generation: 0),
      0,
    );
    expect(
      await applier().applyAllInScope(const [
        (mediaId: 'p1', isVideo: false),
      ], generation: 0),
      0,
    );
  });

  test('nothing with the setting off', () async {
    autoApply = false;
    await store('p1');
    expect(
      await applier().applyInScope('p1', isVideo: false, generation: 0),
      0,
    );
  });

  test('nothing with the feature off', () async {
    marineLifeIdEnabled = false;
    await store('p1');
    expect(
      await applier().applyInScope('p1', isVideo: false, generation: 0),
      0,
    );
  });

  test(
    'one change log operation, labelled marine life identification',
    () async {
      await store('p1');

      await applier().applyInScope('p1', isVideo: false, generation: 0);

      await changeLog.settleAll();
      final ops = await db
          .customSelect('SELECT source, label FROM change_log_operations')
          .get();
      expect(
        [for (final o in ops) o.data],
        [
          {'source': 'automatic', 'label': 'marine_life_id'},
        ],
      );
    },
  );

  test('a run\'s items are one change log operation', () async {
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await store('p1');
    await store('p2');

    final tagged = await applier().applyAllInScope(const [
      (mediaId: 'p1', isVideo: false),
      (mediaId: 'p2', isVideo: false),
    ], generation: 0);

    // One species on two photos is one species tagged.
    expect(tagged, 1);
    await changeLog.settleAll();
    // The test's own photo insert is an operation of its own.
    final ops = await db
        .customSelect(
          "SELECT label FROM change_log_operations "
          "WHERE label = 'marine_life_id'",
        )
        .get();
    expect(ops, hasLength(1));
  });

  test(
    'an item that cannot be tagged does not stop the rest of a run',
    () async {
      await insertTestMedia(id: 'p2', diveId: 'd1');
      await store('p1');
      await store('p2');
      // p1's photo is gone (held for undo, its identifications kept).
      await db.customStatement("DELETE FROM media WHERE id = 'p1'");

      final tagged = await applier().applyAllInScope(const [
        (mediaId: 'p1', isVideo: false),
        (mediaId: 'p2', isVideo: false),
      ], generation: 0);

      expect(tagged, 1);
      final created = await species.findSpeciesByScientificName(
        'Scarus vetula',
      );
      expect(await tags.findTag('p2', created!.id), isNotNull);
    },
  );

  test('another logbook opened while it resolves a species it would '
      'create: no species is created there', () async {
    await store('p1');
    final switching = _SwitchingAcceptor(
      species: species,
      onResolve: () => generation = 1,
    );

    expect(
      await applier(
        acceptor: switching,
      ).applyInScope('p1', isVideo: false, generation: 0),
      0,
    );
    expect(await species.findSpeciesByScientificName('Scarus vetula'), isNull);
  });

  group('another logbook opened', () {
    setUp(() async {
      await insertTestSpecies(
        id: 'sp_queen_parrotfish',
        name: 'Queen Parrotfish',
      );
      await store('p1');
    });

    test('before it applies on an item: nothing is tagged', () async {
      generation = 1;

      expect(
        await applier().applyInScope('p1', isVideo: false, generation: 0),
        0,
      );
      expect(await tags.findTag('p1', 'sp_queen_parrotfish'), isNull);
    });

    test('while it resolves a species: nothing is tagged', () async {
      final switching = _SwitchingAcceptor(
        species: species,
        onResolve: () => generation = 1,
      );

      expect(
        await applier(
          acceptor: switching,
        ).applyInScope('p1', isVideo: false, generation: 0),
        0,
      );
      expect(await tags.findTag('p1', 'sp_queen_parrotfish'), isNull);
    });

    test('before a run applies: nothing is tagged', () async {
      generation = 1;

      expect(
        await applier().applyAllInScope(const [
          (mediaId: 'p1', isVideo: false),
        ], generation: 0),
        0,
      );
      expect(await tags.findTag('p1', 'sp_queen_parrotfish'), isNull);
    });
  });
}
