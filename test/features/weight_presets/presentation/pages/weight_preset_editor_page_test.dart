import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/pages/weight_preset_editor_page.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _RecordingRepo extends WeightPresetRepository {
  final created =
      <({String name, List<WeightEntryDraft> entries, String diverId})>[];
  final updated =
      <({String id, String name, List<WeightEntryDraft> entries})>[];
  WeightPreset? loadReturns;

  @override
  Future<WeightPreset?> getPresetById(String id) async => loadReturns;

  @override
  Future<WeightPreset> createPreset({
    required String diverId,
    required String displayName,
    required List<WeightEntryDraft> entries,
    String notes = '',
  }) async {
    created.add((name: displayName, entries: entries, diverId: diverId));
    return _preset('new', displayName);
  }

  @override
  Future<void> updatePreset({
    required String id,
    required String displayName,
    String? notes,
    required List<WeightEntryDraft> entries,
  }) async {
    updated.add((id: id, name: displayName, entries: entries));
  }
}

WeightPreset _preset(
  String id,
  String name, {
  List<WeightPresetEntry>? entries,
}) {
  final now = DateTime(2026, 1, 1);
  return WeightPreset(
    id: id,
    diverId: 'diver-1',
    displayName: name,
    createdAt: now,
    updatedAt: now,
    entries:
        entries ??
        [
          WeightPresetEntry(
            id: '$id-e0',
            presetId: id,
            weightType: WeightType.belt,
            amountKg: 3.0,
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

  Future<void> pump(WidgetTester tester, {String? presetId}) async {
    final base = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('list')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => WeightPresetEditorPage(presetId: presetId),
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
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
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
    router.push('/edit');
    await tester.pumpAndSettle();
  }

  testWidgets('new: name + a weight row saves via createPreset', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Wetsuit');
    // the single amount field
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    expect(repo.created.single.name, 'Wetsuit');
    expect(repo.created.single.entries, hasLength(1));
    expect(repo.created.single.entries.single.amountKg, closeTo(4.0, 1e-6));
    expect(repo.updated, isEmpty);
  });

  testWidgets('new: refuses to save without a name', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('Give the preset a name'), findsOneWidget);
  });

  testWidgets('new: refuses to save with no positive weight', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Empty');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('Add at least one weight'), findsOneWidget);
  });

  testWidgets('add weight appends a row', (tester) async {
    await pump(tester);
    expect(find.byType(DropdownButtonFormField<WeightType>), findsOneWidget);
    await tester.tap(find.text('Add weight'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<WeightType>), findsNWidgets(2));
  });

  testWidgets('edit: pre-fills the name and entries and calls updatePreset', (
    tester,
  ) async {
    repo.loadReturns = _preset(
      'p1',
      'Drysuit',
      entries: const [
        WeightPresetEntry(
          id: 'p1-e0',
          presetId: 'p1',
          weightType: WeightType.integrated,
          amountKg: 6.0,
        ),
      ],
    );
    await pump(tester, presetId: 'p1');

    expect(find.widgetWithText(TextFormField, 'Drysuit'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Drysuit + argon');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.updated, hasLength(1));
    expect(repo.updated.single.id, 'p1');
    expect(repo.updated.single.name, 'Drysuit + argon');
    expect(repo.updated.single.entries, hasLength(1));
    expect(repo.created, isEmpty);
  });

  testWidgets('edit: a preset that no longer exists shows an error and pops', (
    tester,
  ) async {
    repo.loadReturns = null; // stale deep link / deleted on another device

    await pump(tester, presetId: 'gone');

    expect(find.text('This weighting rig no longer exists.'), findsOneWidget);
    expect(find.text('list'), findsOneWidget); // popped back to the list route
    expect(find.byType(WeightPresetEditorPage), findsNothing);
  });
}
