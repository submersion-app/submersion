// End-to-end test for UniversalAdapter.performImport's post-import photo
// pipeline (M4 Task 11). Wires a real in-memory AppDatabase, a real
// UddfEntityImporter, and a temp mediaRoot; drives the adapter with a
// payload carrying imageRefs + the wizard's resolvedPhotos state; asserts
// that files land on disk and MediaItem rows reference them.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    as wizard
    show ImportEntityType;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';

import '../../../../helpers/test_database.dart';

typedef Override = riverpod.Override;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Testable notifier that lets tests seed a state directly without going
/// through the wizard's pickFile / confirmSource / resolve pipeline.
class _SeededNotifier extends UniversalImportNotifier {
  _SeededNotifier(
    super.ref, {
    required ImportPayload payload,
    List<ResolvedPhoto>? resolvedPhotos,
    bool photoLinkingSkipped = false,
  }) {
    state = state.copyWith(
      payload: payload,
      resolvedPhotos: resolvedPhotos,
      photoLinkingSkipped: photoLinkingSkipped,
    );
  }
}

/// StateNotifier-based settings override that avoids database access.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds a minimal dive payload: one dive with a known sourceUuid, plus
/// [imageRefs] attached to it.
ImportPayload _buildPayload({
  required String diveSourceUuid,
  required List<ImportImageRef> imageRefs,
}) {
  return ImportPayload(
    entities: {
      ImportEntityType.dives: [
        {
          'dateTime': DateTime(2024, 6, 1, 10, 0),
          'maxDepth': 18.0,
          'duration': const Duration(minutes: 40),
          'sourceUuid': diveSourceUuid,
        },
      ],
    },
    imageRefs: imageRefs,
  );
}

Future<domain.Diver> _createTestDiver() async {
  final now = DateTime.now();
  final diver = domain.Diver(
    id: 'diver-photo-test',
    name: 'Test Diver',
    isDefault: true,
    createdAt: now,
    updatedAt: now,
  );
  await DiverRepository().createDiver(diver);
  return diver;
}

/// Builds the provider overrides needed to drive a real `performImport`:
/// real repositories (via the in-memory AppDatabase) plus the testable
/// notifier + mediaRoot override.
List<Override> _overrides({
  required ImportPayload payload,
  required String mediaRoot,
  required domain.Diver diver,
  List<ResolvedPhoto>? resolvedPhotos,
  bool photoLinkingSkipped = false,
}) {
  return [
    universalImportNotifierProvider.overrideWith(
      (ref) => _SeededNotifier(
        ref,
        payload: payload,
        resolvedPhotos: resolvedPhotos,
        photoLinkingSkipped: photoLinkingSkipped,
      ),
    ),
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    currentDiverProvider.overrideWith((ref) async => diver),
    // Real repositories — they all hit the test database via DatabaseService.
    diveRepositoryProvider.overrideWithValue(DiveRepository()),
    siteRepositoryProvider.overrideWithValue(SiteRepository()),
    tripRepositoryProvider.overrideWithValue(TripRepository()),
    equipmentRepositoryProvider.overrideWithValue(EquipmentRepository()),
    equipmentSetRepositoryProvider.overrideWithValue(EquipmentSetRepository()),
    buddyRepositoryProvider.overrideWithValue(BuddyRepository()),
    diveCenterRepositoryProvider.overrideWithValue(DiveCenterRepository()),
    certificationRepositoryProvider.overrideWithValue(
      CertificationRepository(),
    ),
    tagRepositoryProvider.overrideWithValue(TagRepository()),
    diveTypeRepositoryProvider.overrideWithValue(DiveTypeRepository()),
    tankPressureRepositoryProvider.overrideWithValue(TankPressureRepository()),
    courseRepositoryProvider.overrideWithValue(CourseRepository()),
    tankPresetRepositoryProvider.overrideWithValue(TankPresetRepository()),
    // Cache/list providers read by checkDuplicates — return empty.
    allTripsProvider.overrideWith((ref) async => const []),
    sitesProvider.overrideWith((ref) async => const []),
    allEquipmentProvider.overrideWith((ref) async => const []),
    allBuddiesProvider.overrideWith((ref) async => const []),
    allDiveCentersProvider.overrideWith((ref) async => const []),
    allCertificationsProvider.overrideWith((ref) async => const []),
    tagsProvider.overrideWith((ref) async => const []),
    diveTypesProvider.overrideWith((ref) async => const []),
    // Critical: redirect photo writes into a temp directory.
    importedPhotoMediaRootProvider.overrideWith((ref) async => mediaRoot),
  ];
}

Future<void> _runAdapter(
  WidgetTester tester, {
  required List<Override> overrides,
  required Future<void> Function(UniversalAdapter adapter) callback,
}) async {
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  // Run the callback via runAsync so real I/O (SQLite, filesystem) is driven
  // by the real event loop rather than the testWidgets fake async zone — the
  // in-memory Drift instance + per-dive file writes rely on real microtasks
  // that the fake zone would otherwise never step.
  await tester.runAsync(() async {
    await callback(adapter);
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late Directory mediaRoot;
  late Directory sourceDir;

  setUp(() async {
    db = await setUpTestDatabase();
    mediaRoot = Directory.systemTemp.createTempSync('uaw_photo_');
    sourceDir = Directory.systemTemp.createTempSync('uaw_photo_src_');
  });

  tearDown(() async {
    if (mediaRoot.existsSync()) mediaRoot.deleteSync(recursive: true);
    if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  group('UniversalAdapter.performImport writes resolved photos to app media', () {
    testWidgets(
      'files land under mediaRoot/dive/<newDiveId>/ and MediaItems link them',
      (tester) async {
        final diver = await _createTestDiver();
        const diveSourceUuid = 'dive-SRC-UUID-PHOTO-1';
        const ref = ImportImageRef(
          originalPath: '/orig/reef.jpg',
          diveSourceUuid: diveSourceUuid,
          position: 0,
          caption: 'Reef',
        );
        final payload = _buildPayload(
          diveSourceUuid: diveSourceUuid,
          imageRefs: const [ref],
        );
        // Source file that the resolver would have pointed at; adapter
        // copies bytes from here to the mediaRoot during performImport.
        final sourceFile = File('${sourceDir.path}/reef.jpg')
          ..writeAsBytesSync([0xAA, 0xBB, 0xCC]);
        final resolved = [
          ResolvedPhoto(
            ref: ref,
            kind: PhotoResolutionKind.directPath,
            resolvedPath: sourceFile.path,
          ),
        ];

        await _runAdapter(
          tester,
          overrides: _overrides(
            payload: payload,
            mediaRoot: mediaRoot.path,
            diver: diver,
            resolvedPhotos: resolved,
          ),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            await adapter.performImport(bundle, const {
              wizard.ImportEntityType.dives: {0},
            }, const {});
          },
        );

        // Locate the newly-created dive by source UUID → dive_id via the
        // dive_data_sources table.
        final sources = await db.select(db.diveDataSources).get();
        final matching = sources
            .where((s) => s.sourceUuid == diveSourceUuid)
            .toList();
        expect(matching, hasLength(1));
        final newDiveId = matching.single.diveId;

        final expected = File('${mediaRoot.path}/dive/$newDiveId/0-reef.jpg');
        expect(expected.existsSync(), isTrue, reason: 'photo file written');
        expect(expected.readAsBytesSync(), [0xAA, 0xBB, 0xCC]);

        final mediaRepo = MediaRepository();
        final media = await mediaRepo.getMediaForDive(newDiveId);
        expect(media, hasLength(1));
        expect(media.single.diveId, newDiveId);
        expect(media.single.filePath, expected.path);
        expect(media.single.originalFilename, 'reef.jpg');
        expect(media.single.caption, 'Reef');
      },
    );

    testWidgets(
      'photoLinkingSkipped == true: dives land, no photos written, no MediaItems',
      (tester) async {
        final diver = await _createTestDiver();
        const diveSourceUuid = 'dive-SRC-UUID-SKIP';
        const ref = ImportImageRef(
          originalPath: '/orig/x.jpg',
          diveSourceUuid: diveSourceUuid,
        );
        final payload = _buildPayload(
          diveSourceUuid: diveSourceUuid,
          imageRefs: const [ref],
        );

        await _runAdapter(
          tester,
          overrides: _overrides(
            payload: payload,
            mediaRoot: mediaRoot.path,
            diver: diver,
            photoLinkingSkipped: true,
            // Even with resolvedPhotos absent, skip must no-op.
            resolvedPhotos: null,
          ),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            await adapter.performImport(bundle, const {
              wizard.ImportEntityType.dives: {0},
            }, const {});
          },
        );

        // Dive exists.
        final dives = await db.select(db.dives).get();
        expect(dives, hasLength(1));

        // No photos on disk.
        final diveDir = Directory('${mediaRoot.path}/dive/${dives.single.id}');
        expect(diveDir.existsSync(), isFalse);

        // No MediaItem rows.
        final mediaRows = await db.select(db.media).get();
        expect(mediaRows, isEmpty);
      },
    );

    testWidgets(
      'resolvedPhotos == null: dives land, no photos written, no MediaItems',
      (tester) async {
        final diver = await _createTestDiver();
        const diveSourceUuid = 'dive-SRC-UUID-NULL';
        const ref = ImportImageRef(
          originalPath: '/orig/x.jpg',
          diveSourceUuid: diveSourceUuid,
        );
        final payload = _buildPayload(
          diveSourceUuid: diveSourceUuid,
          imageRefs: const [ref],
        );

        await _runAdapter(
          tester,
          overrides: _overrides(
            payload: payload,
            mediaRoot: mediaRoot.path,
            diver: diver,
            resolvedPhotos: null,
          ),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            await adapter.performImport(bundle, const {
              wizard.ImportEntityType.dives: {0},
            }, const {});
          },
        );

        final dives = await db.select(db.dives).get();
        expect(dives, hasLength(1));

        final mediaRows = await db.select(db.media).get();
        expect(mediaRows, isEmpty);
      },
    );

    testWidgets(
      'misses (null resolvedPath) do not fail the import, dives still land',
      (tester) async {
        final diver = await _createTestDiver();
        const diveSourceUuid = 'dive-SRC-UUID-MISS';
        const ref = ImportImageRef(
          originalPath: '/orig/gone.jpg',
          diveSourceUuid: diveSourceUuid,
        );
        final payload = _buildPayload(
          diveSourceUuid: diveSourceUuid,
          imageRefs: const [ref],
        );
        // Miss: null resolvedPath, kind == miss — mimics the resolver
        // giving up for this ref. The user clicked Next anyway.
        const resolved = [
          ResolvedPhoto(ref: ref, kind: PhotoResolutionKind.miss),
        ];

        await _runAdapter(
          tester,
          overrides: _overrides(
            payload: payload,
            mediaRoot: mediaRoot.path,
            diver: diver,
            resolvedPhotos: resolved,
          ),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            await adapter.performImport(bundle, const {
              wizard.ImportEntityType.dives: {0},
            }, const {});
          },
        );

        final dives = await db.select(db.dives).get();
        expect(dives, hasLength(1), reason: 'dive import still succeeds');

        final mediaRows = await db.select(db.media).get();
        expect(mediaRows, isEmpty, reason: 'no MediaItem for missed photo');
      },
    );

    testWidgets(
      'orphan photo (dive deselected as duplicate) is silently dropped',
      (tester) async {
        final diver = await _createTestDiver();
        const keepDive = 'kept-dive';
        const droppedDive = 'dropped-dive';
        // Payload with ONE dive (the kept one). The photo references a
        // different source UUID that was NEVER in the payload — simulates
        // the wizard dropping that dive because of a duplicate check.
        const ref = ImportImageRef(
          originalPath: '/orig/orphan.jpg',
          diveSourceUuid: droppedDive,
        );
        final payload = _buildPayload(
          diveSourceUuid: keepDive,
          imageRefs: const [ref],
        );
        // Source file on disk — even though the adapter will resolve this
        // as an orphan (no dive with the matching source UUID), the
        // resolvedPath must point at a real file so the test exercises
        // the path-based pipeline realistically.
        final sourceFile = File('${sourceDir.path}/orphan.jpg')
          ..writeAsBytesSync([1]);
        final resolved = [
          ResolvedPhoto(
            ref: ref,
            kind: PhotoResolutionKind.directPath,
            resolvedPath: sourceFile.path,
          ),
        ];

        await _runAdapter(
          tester,
          overrides: _overrides(
            payload: payload,
            mediaRoot: mediaRoot.path,
            diver: diver,
            resolvedPhotos: resolved,
          ),
          callback: (adapter) async {
            final bundle = await adapter.buildBundle();
            await adapter.performImport(bundle, const {
              wizard.ImportEntityType.dives: {0},
            }, const {});
          },
        );

        final dives = await db.select(db.dives).get();
        expect(dives, hasLength(1));

        // No MediaItem rows — the orphan photo's dive isn't in the DB.
        final mediaRows = await db.select(db.media).get();
        expect(mediaRows, isEmpty);

        // Nothing under mediaRoot/dive/<droppedDive>.
        expect(
          Directory('${mediaRoot.path}/dive/$droppedDive').existsSync(),
          isFalse,
        );
      },
    );
  });
}
