import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_weight_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_card_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

/// Lead carried as weights gear shows on the dive page's Weight card and in
/// its editor, so a diver can see it is counted and does not log it twice
/// (issue #4442).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2026, 3, 9, 9);
  const belt = DiveWeight(
    id: 'w1',
    diveId: 'dive',
    weightType: WeightType.belt,
    amountKg: 4.5,
  );
  const plate = EquipmentItem(
    id: 'plate',
    name: 'Weighted backplate',
    type: EquipmentType.weights,
    attributes: [
      EquipmentAttribute(
        id: 'plate-dry',
        equipmentId: 'plate',
        key: EquipmentAttrKeys.dryWeightKg,
        valueNum: 2.5,
      ),
    ],
  );
  const unweighed = EquipmentItem(
    id: 'block',
    name: 'Trim block',
    type: EquipmentType.weights,
  );
  const bcd = EquipmentItem(
    id: 'bcd',
    name: 'Wing',
    type: EquipmentType.bcd,
    attributes: [
      EquipmentAttribute(
        id: 'bcd-dry',
        equipmentId: 'bcd',
        key: EquipmentAttrKeys.dryWeightKg,
        valueNum: 3,
      ),
    ],
  );

  Dive dive({List<DiveWeight> weights = const [], List<EquipmentItem>? gear}) =>
      Dive(
        id: 'dive',
        dateTime: t0,
        weights: weights,
        gear: looseGear(gear ?? const []),
      );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(const AppSettings()),
          ),
          weightPresetsProvider.overrideWith((ref) async => const []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpEditor(WidgetTester tester, Dive d) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(d)
      ..openCard('weights');
    addTearDown(controller.dispose);
    await pump(
      tester,
      RecordEditScope<Dive>(
        controller: controller,
        child: DiveWeightsCardEditor(session: controller.session!),
      ),
    );
  }

  group('the weight rows', () {
    // The rows the Weights and buoyancy card lists above the model
    // (issue #5005).
    Finder totalRow(String amount) => find.ancestor(
      of: find.text(amount),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Row &&
            w.children.any(
              (c) =>
                  c is Expanded &&
                  c.child is Text &&
                  (c.child as Text).data == l.diveLog_detail_label_total,
            ),
      ),
    );

    testWidgets('lists weights gear beside the rows and totals both', (
      tester,
    ) async {
      await pump(
        tester,
        DiveWeightRows(
          dive: dive(weights: const [belt], gear: const [plate, bcd]),
        ),
      );

      expect(find.text('Weighted backplate'), findsOneWidget);
      expect(find.text(l.diveLog_detail_weight_fromEquipment), findsOneWidget);
      expect(find.text('2.5 kg'), findsOneWidget);
      expect(totalRow('7.0 kg'), findsOneWidget);
      // A wing's own dry weight is not lead.
      expect(find.text('Wing'), findsNothing);
      // No card or title of its own: the merged card draws those.
      expect(find.byType(Card), findsNothing);
      expect(find.text(l.diveLog_detail_section_weight), findsNothing);
    });

    testWidgets('one entry shows no total row', (tester) async {
      await pump(tester, DiveWeightRows(dive: dive(gear: const [plate])));

      expect(find.text('Weighted backplate'), findsOneWidget);
      expect(find.text('2.5 kg'), findsOneWidget);
      expect(find.text(l.diveLog_detail_label_total), findsNothing);
    });

    testWidgets('leaves out weights gear that declares no mass', (
      tester,
    ) async {
      await pump(
        tester,
        DiveWeightRows(
          dive: dive(weights: const [belt], gear: const [unweighed]),
        ),
      );

      expect(find.text('Trim block'), findsNothing);
      expect(find.text('4.5 kg'), findsOneWidget);
      expect(find.text(l.diveLog_detail_label_total), findsNothing);
    });
  });

  group('the Weight card editor', () {
    testWidgets('says which gear lead is already counted', (tester) async {
      await pumpEditor(
        tester,
        dive(weights: const [belt], gear: const [plate, unweighed]),
      );

      expect(
        find.text(
          l.diveLog_edit_weightGearNote('Weighted backplate', '2.5 kg'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Also counted: 2.5 kg carried as equipment (Weighted backplate)',
        ),
        findsOneWidget,
      );
      // The total counts the gear, as the read card does.
      expect(find.text(l.diveLog_edit_weightTotal('7.0 kg')), findsOneWidget);
    });

    testWidgets('says nothing when no gear carries lead', (tester) async {
      await pumpEditor(
        tester,
        dive(weights: const [belt], gear: const [unweighed, bcd]),
      );

      expect(find.textContaining('Also counted'), findsNothing);
      expect(find.text(l.diveLog_edit_weightTotal('4.5 kg')), findsOneWidget);
    });

    testWidgets('shows a total when gear alone carries lead', (tester) async {
      await pumpEditor(tester, dive(gear: const [plate]));

      expect(find.text(l.diveLog_edit_weightTotal('2.5 kg')), findsOneWidget);
    });
  });
}
