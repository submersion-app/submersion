import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Covers the #1171 seam: the Tags subsection offers a Browse action that
/// opens the previously-used-tag picker, and what the picker returns lands in
/// the form as tag chips.
void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });
  tearDown(tearDownTestDatabase);

  final wreck = Tag(
    id: 'tag-1',
    diverId: 'diver-1',
    name: 'Wreck',
    colorHex: '#3B82F6',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// The edit page runs continuous animations, so pumpAndSettle never
  /// returns; pump a bounded number of frames instead.
  Future<void> pumpFrames(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Browse opens the picker and its pick lands as a tag chip', (
    tester,
  ) async {
    final repository = DiveRepository();
    final overrides = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
          tagStatisticsProvider.overrideWith(
            (ref) async => [TagStatistic(tag: wreck, diveCount: 42)],
          ),
        ].cast(),
        child: const MaterialApp(
          // Every assertion below matches an English label, so pin the
          // locale instead of inheriting the ambient platform one.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(embedded: true)),
        ),
      ),
    );
    await pumpFrames(tester);

    // Expand the Experience group, which houses the Tags subsection.
    final experience = find.textContaining('Experience');
    await tester.ensureVisible(experience.first);
    await pumpFrames(tester, 2);
    if (find.text('Browse').evaluate().isEmpty) {
      await tester.tap(experience.first, warnIfMissed: false);
      await pumpFrames(tester, 5);
    }

    final browse = find.text('Browse');
    expect(browse, findsOneWidget);
    await tester.ensureVisible(browse);
    await pumpFrames(tester, 2);
    await tester.tap(browse);
    await pumpFrames(tester);

    expect(find.byType(TagPickerSheet), findsOneWidget);

    await tester.tap(find.text('Wreck'));
    await pumpFrames(tester, 3);
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1 tag'));
    await pumpFrames(tester);

    // Sheet dismissed, and the picked tag is now a chip on the form.
    expect(find.byType(TagPickerSheet), findsNothing);
    expect(find.widgetWithText(Chip, 'Wreck'), findsOneWidget);
  });
}
