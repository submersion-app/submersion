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

/// Records the delete calls the page makes; every read path is served by the
/// overridden [weightPresetsProvider], so the page never touches a real
/// database here.
class _RecordingRepo extends WeightPresetRepository {
  final deleted = <String>[];

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
        GoRoute(
          path: '/',
          builder: (_, _) => const WeightPresetsPage(),
          routes: [
            GoRoute(
              path: 'new',
              name: 'newWeightPreset',
              builder: (_, _) => const Scaffold(body: Text('editor: new')),
            ),
            GoRoute(
              path: ':presetId/edit',
              name: 'editWeightPreset',
              builder: (_, s) => Scaffold(
                body: Text('editor: ${s.pathParameters['presetId']}'),
              ),
            ),
          ],
        ),
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

  testWidgets('the add button is a floating action button, not an app-bar '
      'action', (tester) async {
    await pump(tester, []);

    expect(
      find.widgetWithIcon(FloatingActionButton, Icons.add),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.add),
      ),
      findsNothing,
    );
  });

  testWidgets('the add button opens the new-preset editor', (tester) async {
    await pump(tester, []);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('editor: new'), findsOneWidget);
  });

  testWidgets('tapping a preset opens the editor for it', (tester) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.text('Drysuit'));
    await tester.pumpAndSettle();

    expect(find.text('editor: p1'), findsOneWidget);
  });

  testWidgets('each preset offers edit and delete icons, no overflow menu', (
    tester,
  ) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('the edit icon opens the editor for that preset', (tester) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('editor: p1'), findsOneWidget);
  });

  testWidgets('delete asks first, then removes the preset', (tester) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // The confirm dialog names the preset.
    expect(find.textContaining('Drysuit'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['p1']);
  });

  testWidgets('cancelling the delete dialog keeps the preset', (tester) async {
    await pump(tester, [_preset('p1', 'Drysuit')]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deleted, isEmpty);
  });
}
