import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Widget-level regression for issue #3901: the form's time inputs hold whole
/// minutes, and saving an unrelated edit used to write those minutes over the
/// stored seconds. This drives the real edit flow against a real database so
/// the assertion is on the stored row.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    required void Function(String) onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Renames the dive, the edit unrelated to any time, and saves.
  Future<void> renameAndSave(WidgetTester tester) async {
    final nameRow = find
        .ancestor(of: find.text('Name'), matching: find.byType(FormRow))
        .first;
    await tester.ensureVisible(nameRow);
    await tester.pumpAndSettle();
    await tester.tap(nameRow);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: nameRow, matching: find.byType(TextField)),
      'Renamed',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  final entry = DateTime.utc(2026, 1, 1, 10, 0, 50);
  final exit = DateTime.utc(2026, 1, 1, 10, 50, 10);

  testWidgets('an unrelated edit keeps entry, exit and durations exact', (
    tester,
  ) async {
    final dive = await repository.createDive(
      Dive(
        id: 'dive-3901',
        dateTime: entry,
        entryTime: entry,
        exitTime: exit,
        bottomTime: const Duration(seconds: 2409),
        runtime: const Duration(seconds: 2960),
      ),
    );

    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);
    await renameAndSave(tester);

    expect(savedId, isNotNull, reason: 'save should complete');
    final reloaded = (await repository.getDiveById(dive.id))!;
    expect(reloaded.name, 'Renamed');
    expect(reloaded.dateTime, entry);
    expect(reloaded.entryTime, entry);
    expect(reloaded.exitTime, exit);
    expect(reloaded.runtime, const Duration(seconds: 2960));
    expect(reloaded.bottomTime, const Duration(seconds: 2409));
  });

  testWidgets('an unrelated edit does not store the estimated exit', (
    tester,
  ) async {
    final dive = await repository.createDive(
      Dive(
        id: 'dive-3901-no-exit',
        dateTime: entry,
        entryTime: entry,
        bottomTime: const Duration(seconds: 2409),
        runtime: const Duration(seconds: 2960),
      ),
    );

    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);
    await renameAndSave(tester);

    expect(savedId, isNotNull, reason: 'save should complete');
    final reloaded = (await repository.getDiveById(dive.id))!;
    expect(reloaded.exitTime, isNull);
    expect(reloaded.runtime, const Duration(seconds: 2960));
    expect(reloaded.bottomTime, const Duration(seconds: 2409));
  });
}
