import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_weight_entry_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/shared_items_fixture.dart';
import '../../../../../../helpers/test_database.dart';

/// The Weight card of the dive page, edited in place (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2026, 3, 9, 9);
  const belt = DiveWeight(
    id: 'w1',
    diveId: 'dive',
    weightType: WeightType.belt,
    amountKg: 4.5,
  );
  const pocket = DiveWeight(
    id: 'w2',
    diveId: 'dive',
    weightType: WeightType.integrated,
    amountKg: 2,
    label: 'Left pocket',
  );
  final dive = Dive(
    id: 'dive',
    dateTime: t0,
    weights: const [belt, pocket],
    weightingFeedback: WeightingFeedback.overweighted,
    weightingFeedbackKg: 1.5,
  );
  const imperial = AppSettings(weightUnit: WeightUnit.pounds);
  final preset = WeightPreset(
    id: 'p',
    diverId: 'me',
    displayName: 'Warm water',
    entries: const [
      WeightPresetEntry(
        id: 'e',
        presetId: 'p',
        weightType: WeightType.integrated,
        amountKg: 3,
      ),
    ],
    createdAt: t0,
    updatedAt: t0,
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pumpEditor(
    WidgetTester tester,
    Dive d, {
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(d)
      ..openCard('weights');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(settings),
          ),
          weightPresetsProvider.overrideWith((ref) async => [preset]),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: Column(
                  children: [
                    DiveWeightsCardEditor(session: controller.session!),
                    const TextField(key: ValueKey('elsewhere')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Finder amountOf(String id) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is DiveWeightEntryRow && w.weight.id == id,
    ),
    matching: find.byType(TextFormField),
  );

  for (final (name, settings) in [
    ('metric', const AppSettings()),
    ('imperial', imperial),
  ]) {
    testWidgets('opening and tapping every row leaves the sitting clean, '
        '$name', (tester) async {
      final c = await pumpEditor(tester, dive, settings: settings);
      final fields = find.descendant(
        of: find.byType(DiveWeightsCardEditor),
        matching: find.byType(EditableText),
      );
      expect(fields, findsWidgets);
      for (var i = 0; i < fields.evaluate().length; i++) {
        await tester.tap(fields.at(i));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('elsewhere')));
      await tester.pumpAndSettle();

      expect(c.session!.isDirty, isFalse);
    });
  }

  testWidgets('a weight added, changed and removed; the total follows', (
    tester,
  ) async {
    final c = await pumpEditor(tester, dive);
    expect(find.text(l.diveLog_edit_weightTotal('6.5 kg')), findsOneWidget);

    await tester.tap(find.text(l.diveLog_edit_addWeightEntry));
    await tester.pumpAndSettle();
    final added = c.session!.valueOf(diveWeightsField).last;
    expect(added.amountKg, 0);
    expect(c.session!.changedCardIds, {'weights'});

    await tester.enterText(amountOf(added.id).first, '2');
    await tester.pumpAndSettle();
    expect(c.session!.valueOf(diveWeightsField).last.amountKg, 2);
    expect(find.text(l.diveLog_edit_weightTotal('8.5 kg')), findsOneWidget);

    tester
        .widget<DiveWeightEntryRow>(
          find.byWidgetPredicate(
            (w) => w is DiveWeightEntryRow && w.weight.id == added.id,
          ),
        )
        .onRemove();
    await tester.pumpAndSettle();
    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('an amount that cannot be read refuses Done', (tester) async {
    final c = await pumpEditor(tester, dive);

    await tester.enterText(amountOf('w1').first, '4.5.1');
    await tester.pump();
    await tester.pump();

    expect(c.invalidCardIds, {'weights'});
    c.closeCard('weights');
    expect(c.openCardIds, contains('weights'));
  });

  testWidgets('a preset replaces the weights', (tester) async {
    final c = await pumpEditor(tester, dive);

    await tester.tap(find.text(l.diveLog_edit_weightPreset_use));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warm water'));
    await tester.pumpAndSettle();

    final rows = c.session!.valueOf(diveWeightsField);
    expect(rows.single.amountKg, 3);
    expect(find.byType(DiveWeightEntryRow), findsOneWidget);
  });

  testWidgets('a change that arrives underneath is shown in the rows', (
    tester,
  ) async {
    final c = await pumpEditor(tester, dive);

    // A sync: the belt's amount changes while the weights are untouched.
    c.storedChanged(
      dive.copyWith(weights: [belt.copyWith(amountKg: 6), pocket]),
    );
    await tester.pumpAndSettle();

    final shown = tester.widget<EditableText>(
      find.descendant(
        of: amountOf('w1').first,
        matching: find.byType(EditableText),
      ),
    );
    expect(shown.controller.text, '6');
  });

  testWidgets('Save as preset creates it at once, and the sitting is '
      'untouched', (tester) async {
    await seedDivers(DatabaseService.instance.database, ['me']);
    final c = await pumpEditor(tester, dive);

    await tester.tap(find.text(l.diveLog_edit_weightPreset_save));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Cold water');
    await tester.tap(find.text(l.common_action_save));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(
      () => WeightPresetRepository().getPresets(diverId: 'me'),
    );
    expect(saved!.map((p) => p.displayName), ['Cold water']);
    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('Save as preset that cannot be written says so, and nothing '
      'is left unhandled', (tester) async {
    // No diver 'me' in the database: the preset's insert is refused.
    final c = await pumpEditor(tester, dive);

    await tester.tap(find.text(l.diveLog_edit_weightPreset_save));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Cold water');
    await tester.tap(find.text(l.common_action_save));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining(l.common_label_error), findsOneWidget);
    expect(
      find.text(l.diveLog_edit_weightPreset_saved('Cold water')),
      findsNothing,
    );
    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('feedback over with an amount, in pounds, saves kilograms', (
    tester,
  ) async {
    final c = await pumpEditor(
      tester,
      Dive(id: 'dive', dateTime: t0),
      settings: imperial,
    );

    await tester.tap(find.text(l.diveLog_edit_weightFeedback_over));
    await tester.pumpAndSettle();
    expect(find.byType(RecordNumberRow<Dive>), findsOneWidget);
    await tester.tap(find.text(l.diveLog_edit_weightFeedback_amount('lbs')));
    await tester.pump();
    final amount = find.descendant(
      of: find.byType(RecordNumberRow<Dive>),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(amount, '4');
    await tester.enterText(amount, '44');
    await tester.pumpAndSettle();

    final s = c.session!;
    expect(
      s.valueOf(diveWeightingFeedbackField),
      WeightingFeedback.overweighted,
    );
    expect(s.valueOf(diveWeightingFeedbackKgField), closeTo(19.958, 0.01));
  });

  testWidgets('correct hides the amount', (tester) async {
    await pumpEditor(tester, dive);
    expect(find.byType(RecordNumberRow<Dive>), findsOneWidget);

    await tester.tap(find.text(l.diveLog_edit_weightFeedback_correct));
    await tester.pumpAndSettle();

    expect(find.byType(RecordNumberRow<Dive>), findsNothing);
  });
}
