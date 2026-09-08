import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/pages/weight_presets_page.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Records the rename/delete calls the page makes; every read path is served
/// by the overridden [weightPresetsProvider], so the page never touches a
/// real database here.
class _RecordingRepo extends WeightPresetRepository {
  final renamed = <({String id, String name})>[];
  final deleted = <String>[];

  @override
  Future<void> renamePreset({
    required String id,
    required String displayName,
    String? notes,
  }) async {
    renamed.add((id: id, name: displayName));
  }

  @override
  Future<void> deletePreset(String id) async => deleted.add(id);
}

WeightPreset _preset(String id, String name, {int entries = 2}) {
  final now = DateTime(2026, 1, 1);
  return WeightPreset(
    id: id,
    diverId: 'diver-1',
    displayName: name,
    createdAt: now,
    updatedAt: now,
    entries: [
      for (var i = 0; i < entries; i++)
        WeightPresetEntry(
          id: '$id-e$i',
          presetId: id,
          weightType: WeightType.belt,
          amountKg: 2.0,
          sortOrder: i,
        ),
    ],
  );
}

void main() {
  late _RecordingRepo repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = _RecordingRepo();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(WidgetTester tester, List<WeightPreset> presets) async {
    final base = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WeightPresetsPage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.cast<Override>(),
          weightPresetRepositoryProvider.overrideWithValue(repo),
          weightPresetsProvider.overrideWith((ref) async => presets),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the diver presets with an entry-count subtitle', (
    tester,
  ) async {
    await pump(tester, [
      _preset('p1', 'Drysuit', entries: 3),
      _preset('p2', 'Wetsuit 5mm', entries: 1),
    ]);

    expect(find.text('Drysuit'), findsOneWidget);
    expect(find.text('Wetsuit 5mm'), findsOneWidget);
    expect(find.textContaining('3 weights'), findsOneWidget);
    expect(find.textContaining('1 weight ·'), findsOneWidget);
  });

  testWidgets('shows the empty-state copy when the diver has no presets', (
    tester,
  ) async {
    await pump(tester, []);

    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('dive editor'), findsOneWidget);
  });

  testWidgets('the rename action writes the new name through the repository', (
    tester,
  ) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Drysuit + argon');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.renamed, [(id: 'p1', name: 'Drysuit + argon')]);
  });

  testWidgets('an unchanged name is not written back', (tester) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.renamed, isEmpty);
  });

  testWidgets('delete asks first, then removes the preset', (tester) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // The confirm dialog names the preset.
    expect(find.textContaining('Drysuit'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['p1']);
  });

  testWidgets('cancelling the delete dialog keeps the preset', (tester) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deleted, isEmpty);
  });
}
