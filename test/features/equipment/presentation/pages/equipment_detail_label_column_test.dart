import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

import '../../../../helpers/detail_row_finders.dart';

/// The Details card's values sit beside their labels on one shared column
/// instead of at the card's far edge (issue #3678).
void main() {
  const equipment = EquipmentItem(
    id: 'equip-columns',
    name: 'First stage',
    type: EquipmentType.regulator,
    brand: 'Apeks',
    model: 'XTX50',
    serialNumber: 'AX-55120',
  );

  Future<void> pumpWide(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          // No diver profile: the page treats every item as the viewer's own
          // (issue #2046), and the menu waits for this to resolve.
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentItemProvider(
            equipment.id,
          ).overrideWith((ref) async => equipment),
          equipmentDiveCountProvider(
            equipment.id,
          ).overrideWith((ref) async => 3),
          equipmentTripCountProvider(
            equipment.id,
          ).overrideWith((ref) async => 0),
          equipmentComponentsProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          equipmentPartOfProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            equipment.id,
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: equipment.id,
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: equipment.id,
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          serviceRecordNotifierProvider(
            equipment.id,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: equipment.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Details values share one column beside the labels', (
    tester,
  ) async {
    await pumpWide(tester);

    final column = detailValueLeft(tester, 'Status');
    for (final label in ['Brand', 'Model', 'Serial Number', 'Dives']) {
      expect(detailValueLeft(tester, label), column, reason: label);
    }
    // Beside the labels, not out at the far edge of a 1400 px window.
    expect(column, lessThan(700));
  });

  testWidgets('the Dives count stays tappable, and a zero count does not', (
    tester,
  ) async {
    await pumpWide(tester);

    InkWell inkWellOf(String text) => tester.widget<InkWell>(
      find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first,
    );
    // Three dives open the dive list; no trips leave nothing to open.
    expect(inkWellOf('3 dives').onTap, isNotNull);
    expect(inkWellOf('0 trips').onTap, isNull);
  });

  testWidgets('the Dives chevron follows the count', (tester) async {
    await pumpWide(tester);

    final count = find.text('3 dives');
    final chevron = find.descendant(
      of: detailRowFor('Dives'),
      matching: find.byIcon(Icons.chevron_right),
    );
    expect(tester.getTopLeft(chevron).dx, tester.getTopRight(count).dx + 4);
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
