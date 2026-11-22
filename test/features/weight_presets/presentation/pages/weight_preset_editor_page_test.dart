import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/pages/weight_preset_editor_page.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _RecordingRepo extends WeightPresetRepository {
  final created =
      <
        ({
          String? id,
          String name,
          List<WeightEntryDraft> entries,
          String diverId,
        })
      >[];
  final updated =
      <({String id, String name, List<WeightEntryDraft> entries})>[];
  WeightPreset? loadReturns;

  /// Thrown by the load when set.
  Object? loadError;

  @override
  Future<WeightPreset?> getPresetById(String id) async {
    final error = loadError;
    if (error != null) throw error;
    return loadReturns;
  }

  @override
  Future<WeightPreset> createPreset({
    String? id,
    required String diverId,
    required String displayName,
    required List<WeightEntryDraft> entries,
    String notes = '',
  }) async {
    created.add((
      id: id,
      name: displayName,
      entries: entries,
      diverId: diverId,
    ));
    return _preset('new', displayName);
  }

  final renamed = <({String id, String name})>[];

  @override
  Future<void> renamePreset({
    required String id,
    required String displayName,
    String? notes,
  }) async {
    renamed.add((id: id, name: displayName));
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

/// Writes the preset for real, then fails: the Save's one transaction must
/// take the written rows back with it.
class _FailsAfterWritingRepo extends WeightPresetRepository {
  @override
  Future<WeightPreset> createPreset({
    String? id,
    required String diverId,
    required String displayName,
    required List<WeightEntryDraft> entries,
    String notes = '',
  }) async {
    await super.createPreset(
      id: id,
      diverId: diverId,
      displayName: displayName,
      entries: entries,
      notes: notes,
    );
    throw StateError('write refused');
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

/// A row's amount field (its label is the weight unit).
Finder _amountField({String unit = 'kg'}) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == unit,
);

/// A row's optional name field (issue #956).
Finder _nameField() => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == 'Name (optional)',
);

void main() {
  late _RecordingRepo repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = _RecordingRepo();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(
    WidgetTester tester, {
    String? presetId,
    WeightPresetRepository? repository,
    String diverId = 'diver-1',
    bool pounds = false,
  }) async {
    final settings = MockSettingsNotifier();
    if (pounds) await settings.setWeightUnit(WeightUnit.pounds);
    final base = await getBaseOverrides(settingsNotifier: settings);
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
          weightPresetRepositoryProvider.overrideWithValue(repository ?? repo),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
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
    await tester.enterText(_amountField().last, '4');
    await tester.pump();
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
    await tester.enterText(_amountField().last, '4');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('Give the preset a name'), findsOneWidget);
  });

  testWidgets('new: refuses to save with no positive weight', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Empty');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('Add at least one weight'), findsOneWidget);
  });

  testWidgets('new: an unreadable weight blocks save and says why (#1900)', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Wetsuit');
    await tester.enterText(_amountField().last, '4..5');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.textContaining('Enter a valid number'), findsOneWidget);
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
    await tester.enterText(_amountField().first, '7');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.updated, hasLength(1));
    expect(repo.updated.single.id, 'p1');
    expect(repo.updated.single.name, 'Drysuit + argon');
    expect(repo.updated.single.entries.single.amountKg, closeTo(7.0, 1e-6));
    expect(repo.created, isEmpty);
  });

  testWidgets('edit: a rename alone leaves the stored weights untouched', (
    tester,
  ) async {
    repo.loadReturns = _preset('p1', 'Drysuit');
    await pump(tester, presetId: 'p1');
    await tester.enterText(find.byType(TextFormField).first, 'Drysuit cold');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.renamed, [(id: 'p1', name: 'Drysuit cold')]);
    expect(repo.updated, isEmpty);
  });

  testWidgets('edit: changing a weight keeps a name synced meanwhile', (
    tester,
  ) async {
    repo.loadReturns = _preset('p1', 'Drysuit');
    await pump(tester, presetId: 'p1');
    repo.loadReturns = _preset('p1', 'Drysuit, from the phone');
    await tester.enterText(_amountField().first, '5');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.updated.single.name, 'Drysuit, from the phone');
    expect(repo.updated.single.entries.single.amountKg, closeTo(5.0, 1e-6));
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

  testWidgets('edit: a preset deleted elsewhere while edited is refused at '
      'Save, saying so', (tester) async {
    repo.loadReturns = _preset('p1', 'Drysuit');
    await pump(tester, presetId: 'p1');
    repo.loadReturns = null; // deleted by a sync meanwhile
    await tester.enterText(find.byType(TextFormField).first, 'Drysuit 2');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.updated, isEmpty);
    expect(repo.renamed, isEmpty);
    expect(find.text('This weighting rig no longer exists.'), findsOneWidget);
    expect(find.byType(WeightPresetEditorPage), findsOneWidget);
  });

  testWidgets(
    'edit: in pounds a weight left alone keeps its stored kilograms',
    (tester) async {
      repo.loadReturns = _preset(
        'p1',
        'Drysuit',
        entries: const [
          WeightPresetEntry(
            id: 'p1-e0',
            presetId: 'p1',
            weightType: WeightType.belt,
            amountKg: 1.0,
          ),
          WeightPresetEntry(
            id: 'p1-e1',
            presetId: 'p1',
            weightType: WeightType.trimWeights,
            amountKg: 2.0,
          ),
        ],
      );
      await pump(tester, presetId: 'p1', pounds: true);
      expect(find.widgetWithText(TextFormField, '2.205'), findsOneWidget);
      await tester.enterText(_amountField(unit: 'lbs').last, '10');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = repo.updated.single.entries;
      expect(saved.first.amountKg, 1.0);
      expect(saved.last.amountKg, closeTo(10 / 2.20462, 1e-3));
    },
  );

  testWidgets('edit: changing one weight keeps another synced meanwhile', (
    tester,
  ) async {
    WeightPreset preset({required double trimKg, String trimLabel = ''}) =>
        _preset(
          'p1',
          'Drysuit',
          entries: [
            const WeightPresetEntry(
              id: 'e0',
              presetId: 'p1',
              weightType: WeightType.belt,
              amountKg: 3.0,
            ),
            WeightPresetEntry(
              id: 'e1',
              presetId: 'p1',
              weightType: WeightType.trimWeights,
              amountKg: trimKg,
              label: trimLabel,
            ),
          ],
        );
    repo.loadReturns = preset(trimKg: 1.0);
    await pump(tester, presetId: 'p1');
    // The phone syncs a heavier trim weight, with a name, while the page
    // is open.
    repo.loadReturns = preset(trimKg: 1.5, trimLabel: 'Pockets');
    await tester.enterText(_amountField().first, '4');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = repo.updated.single.entries;
    expect(saved.first.amountKg, closeTo(4.0, 1e-6));
    expect(saved.last.amountKg, 1.5);
    expect(saved.last.label, 'Pockets');
  });

  testWidgets('edit: a preset that fails to load says so and leaves', (
    tester,
  ) async {
    repo.loadError = StateError('database closed');

    await pump(tester, presetId: 'p1');

    expect(find.textContaining('database closed'), findsOneWidget);
    expect(find.text('list'), findsOneWidget);
    expect(find.byType(WeightPresetEditorPage), findsNothing);
  });

  group('weight names (#956)', () {
    testWidgets('new: a row\'s name saves with its entry', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Sidemount');
      await tester.enterText(_amountField().last, '2');
      await tester.enterText(_nameField().last, 'Top pocket');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.created.single.entries.single.label, 'Top pocket');
    });

    testWidgets('edit: an entry\'s name is pre-filled and saved back', (
      tester,
    ) async {
      repo.loadReturns = _preset(
        'p1',
        'Sidemount',
        entries: const [
          WeightPresetEntry(
            id: 'p1-e0',
            presetId: 'p1',
            weightType: WeightType.trimWeights,
            amountKg: 2.0,
            label: 'Top pocket',
          ),
        ],
      );
      await pump(tester, presetId: 'p1');

      expect(find.widgetWithText(TextFormField, 'Top pocket'), findsOneWidget);
      // Save is offered once something changed: change the weight, so the
      // rows are written and the name must go with them.
      await tester.enterText(_amountField().first, '3');
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.updated.single.entries.single.label, 'Top pocket');
    });

    testWidgets('deleting a middle row keeps the others\' names and types', (
      tester,
    ) async {
      repo.loadReturns = _preset(
        'p1',
        'Sidemount',
        entries: const [
          WeightPresetEntry(
            id: 'e0',
            presetId: 'p1',
            weightType: WeightType.trimWeights,
            amountKg: 2.0,
            label: 'Top pocket',
          ),
          WeightPresetEntry(
            id: 'e1',
            presetId: 'p1',
            weightType: WeightType.ankleWeights,
            amountKg: 1.0,
            label: 'Ankles',
          ),
          WeightPresetEntry(
            id: 'e2',
            presetId: 'p1',
            weightType: WeightType.belt,
            amountKg: 3.0,
            label: 'Belt',
          ),
        ],
      );
      await pump(tester, presetId: 'p1');

      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = repo.updated.single.entries;
      expect(saved.map((e) => e.label), ['Top pocket', 'Belt']);
      expect(saved.map((e) => e.weightType), [
        WeightType.trimWeights,
        WeightType.belt,
      ]);
      expect(find.text('Ankle Weights'), findsNothing);
    });
  });

  testWidgets('edit: a preset with no entries starts with one blank row', (
    tester,
  ) async {
    repo.loadReturns = _preset('p1', 'Empty', entries: const []);
    await pump(tester, presetId: 'p1');

    expect(find.byType(DropdownButtonFormField<WeightType>), findsOneWidget);
    expect(_nameField(), findsOneWidget);
  });

  testWidgets('a row\'s type change is saved', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Ankles');
    await tester.enterText(_amountField().last, '1');
    await tester.tap(find.text('Weight Belt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankle Weights').last);
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      repo.created.single.entries.single.weightType,
      WeightType.ankleWeights,
    );
  });

  group('on the shared Cancel and Save bar', () {
    VoidCallback? saveOnPressed(WidgetTester tester) => tester
        .widget<AppBarTextAction>(find.widgetWithText(AppBarTextAction, 'Save'))
        .onPressed;

    Future<void> back(WidgetTester tester) async {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.maybePop());
      await tester.pumpAndSettle();
    }

    testWidgets('a new preset opens on the tinted bar from its first frame', (
      tester,
    ) async {
      final base = await getBaseOverrides();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('list')),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const WeightPresetEditorPage(),
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
      router.push('/new');
      // The first frame that builds the editor, offstage or not, already
      // shows the bar.
      Finder built(Type type) => find.byType(type, skipOffstage: false);
      for (
        var i = 0;
        i < 5 && built(WeightPresetEditorPage).evaluate().isEmpty;
        i++
      ) {
        await tester.pump();
      }
      expect(built(WeightPresetEditorPage), findsOneWidget);
      expect(built(RecordEditBar), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('a new preset with its one blank row is unchanged', (
      tester,
    ) async {
      await pump(tester);
      expect(saveOnPressed(tester), isNull);
      await back(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('adding a row is a change; removing it again is not', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Add weight'));
      await tester.pumpAndSettle();
      expect(saveOnPressed(tester), isNotNull);
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      expect(saveOnPressed(tester), isNull);
    });

    testWidgets('Back after editing an amount asks; Discard leaves the list', (
      tester,
    ) async {
      repo.loadReturns = _preset('p1', 'Drysuit');
      await pump(tester, presetId: 'p1');
      await tester.enterText(_amountField().first, '5');
      await tester.pumpAndSettle();
      await back(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(WeightPresetEditorPage), findsNothing);
      expect(find.text('list'), findsOneWidget);
      expect(repo.updated, isEmpty);
    });

    testWidgets('a new preset is created under the page id', (tester) async {
      await pump(tester);
      final host =
          tester.state(find.byType(WeightPresetEditorPage)) as RecordEditorHost;
      await tester.enterText(find.byType(TextFormField).first, 'Wetsuit');
      await tester.enterText(_amountField().last, '4');
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.created.single.id, host.newEditorRecordId);
      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('a create that throws keeps the rows and writes no preset', (
      tester,
    ) async {
      final now = DateTime(2026, 1, 1);
      final diverId = (await DiverRepository().createDiver(
        Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
      )).id;
      await pump(
        tester,
        repository: _FailsAfterWritingRepo(),
        diverId: diverId,
      );
      await tester.enterText(find.byType(TextFormField).first, 'Wetsuit');
      await tester.enterText(_amountField().last, '4');
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(WeightPresetEditorPage), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Wetsuit'), findsOneWidget);
      expect(saveOnPressed(tester), isNotNull);
      final rows = await DatabaseService.instance.database
          .customSelect('SELECT id FROM weight_presets')
          .get();
      expect(rows, isEmpty);
    });
  });
}
