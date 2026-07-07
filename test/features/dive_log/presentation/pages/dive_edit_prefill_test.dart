import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'dart:io';

import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Filesystem-free stand-in: real file IO deadlocks the FakeAsync test
/// zone under coverage instrumentation, so the fake only records calls.
class _RecordingMediaImportService implements MediaImportService {
  final bool shouldThrow;
  int localFileCalls = 0;

  _RecordingMediaImportService({this.shouldThrow = false});

  @override
  Future<MediaItem> importLocalFileForDive({
    required File sourceFile,
    required String diveId,
    DateTime? takenAt,
  }) async {
    localFileCalls++;
    if (shouldThrow) {
      throw const FileSystemException('attach failed');
    }
    return MediaItem(
      id: 'scan-1',
      diveId: diveId,
      mediaType: MediaType.photo,
      takenAt: DateTime(2024),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('\${invocation.memberName}');
}

void main() {
  group('DiveEditPage prefill', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<void> pumpEditPage(
      WidgetTester tester, {
      DivePrefill? prefill,
      void Function(String)? onSaved,
      List<Override> extraOverrides = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith((ref) {
              return DiveListNotifier(repository, ref);
            }),
            customTankPresetsProvider.overrideWith((ref) async => []),
            ...extraOverrides,
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(
                embedded: true,
                prefill: prefill,
                onSaved: onSaved,
              ),
            ),
          ),
        ),
      );
      // No pumpAndSettle: the new-dive path starts a 10s GPS capture
      // whose pending timer never settles in tests.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('prefill populates create-mode fields', (tester) async {
      final prefill = DivePrefill(
        diveNumber: 66,
        dateTime: DateTime(2006, 2, 6, 10, 0),
        hasTimeOfDay: true,
        durationMinutes: 32,
        maxDepthMeters: 21.0,
        waterTempCelsius: 22.8,
        notes: 'WE SAW A HUMPBACK WHALE',
        rating: 5,
        startPressureBar: 206.8,
        endPressureBar: 110.3,
        importSource: 'ocr',
      );
      await pumpEditPage(tester, prefill: prefill);
      // The form renders values as FormRow text ('45 min' style), so match
      // by content rather than widget type.
      expect(find.textContaining('66'), findsWidgets);
      expect(find.textContaining('32 min'), findsWidgets);
      expect(find.text('WE SAW A HUMPBACK WHALE'), findsOneWidget);
      // Depth shown in the active display unit (metric default in tests).
      expect(find.textContaining('21.0'), findsWidgets);
    });

    testWidgets('no prefill leaves create mode unchanged', (tester) async {
      await pumpEditPage(tester);
      expect(find.text('WE SAW A HUMPBACK WHALE'), findsNothing);
      expect(find.byType(DiveEditPage), findsOneWidget);
    });

    testWidgets('full prefill covers site, tank, temps, and weight', (
      tester,
    ) async {
      final prefill = DivePrefill(
        dateTime: DateTime(2023, 5, 14),
        maxDepthMeters: 11.1,
        airTempCelsius: 24,
        waterTempCelsius: 25,
        weightKg: 5,
        site: const DiveSite(id: 'site-1', name: 'Pinnacle, Sodwana Bay'),
        // Only the cylinder volume, so every tank-prefill disjunct
        // (start, end, o2) evaluates before the volume one matches.
        cylinderVolumeLiters: 11.1,
        importSource: 'ocr',
      );
      await pumpEditPage(tester, prefill: prefill);
      expect(find.textContaining('Pinnacle, Sodwana Bay'), findsWidgets);
      expect(find.byType(DiveEditPage), findsOneWidget);
    });

    testWidgets('saving with a photo path attaches the scanned page', (
      tester,
    ) async {
      final mediaService = _RecordingMediaImportService();

      String? savedId;
      await pumpEditPage(
        tester,
        prefill: const DivePrefill(
          maxDepthMeters: 18,
          photoPath: '/scanned/page.jpg',
          importSource: 'ocr',
        ),
        onSaved: (id) => savedId = id,
        extraOverrides: [
          mediaImportServiceProvider.overrideWithValue(mediaService),
        ],
      );

      await tester.tap(find.text('Save'));
      for (var i = 0; i < 100 && savedId == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(savedId, isNotNull);
      expect(mediaService.localFileCalls, 1);
    });

    testWidgets('photo attach failure never blocks the save', (tester) async {
      final mediaService = _RecordingMediaImportService(shouldThrow: true);

      String? savedId;
      await pumpEditPage(
        tester,
        prefill: const DivePrefill(
          photoPath: '/scanned/missing.jpg',
          importSource: 'ocr',
        ),
        onSaved: (id) => savedId = id,
        extraOverrides: [
          mediaImportServiceProvider.overrideWithValue(mediaService),
        ],
      );

      await tester.tap(find.text('Save'));
      for (var i = 0; i < 100 && savedId == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(savedId, isNotNull);
      expect(mediaService.localFileCalls, 1);
    });
  });
}
