import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The same fake `equipment_detail_service_test.dart` keeps private: the
/// history section needs a notifier that never touches the database.
class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final t0 = DateTime(2025, 1, 1);
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );

  ServiceClockStatus hoseSwap({
    String equipmentId = 'hose',
    ServiceClockSeverity severity = ServiceClockSeverity.overdue,
    DateTime? dueDate,
  }) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's1',
      equipmentId: equipmentId,
      serviceKindId: 'hose-swap',
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: ServiceKind(
      id: 'hose-swap',
      name: 'Hose replacement',
      defaultIntervalDays: 1825,
      isBuiltIn: false,
      createdAt: t0,
      updatedAt: t0,
    ),
    anchor: t0,
    dueDate: dueDate ?? DateTime(2026, 1, 1),
    severity: severity,
    now: DateTime(2026, 7, 1),
  );

  RollupClock overdueOnHose() => (
    ownerId: 'hose',
    ownerName: 'Necklace hose',
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'hose',
        serviceKindId: 'hose-swap',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'hose-swap',
        name: 'Hose replacement',
        defaultIntervalDays: 1825,
        isBuiltIn: false,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 7, 1),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Map<String, RollupClock> rollup, {
    List<ServiceClockStatus> own = const [],
    bool embedded = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider('reg').overrideWith((ref) async => reg),
          equipmentDiveCountProvider('reg').overrideWith((ref) async => 0),
          equipmentTripCountProvider('reg').overrideWith((ref) async => 0),
          serviceRecordNotifierProvider(
            'reg',
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
          serviceClockStatusesProvider('reg').overrideWith((ref) async => own),
          equipmentComponentsProvider(
            'reg',
          ).overrideWith((ref) async => const []),
          equipmentPartOfProvider('reg').overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            'reg',
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(
            'reg',
          ).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: 'reg',
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: 'reg',
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider('reg').overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            'reg',
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          equipmentRollupClockProvider.overrideWith((ref) async => rollup),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: 'reg', embedded: embedded),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The banner used to say only "Service is overdue!". It now names the
  // service, the part that owns it, and when it fell due (#2260).
  testWidgets('the header names the overdue part and when it fell due', (
    tester,
  ) async {
    await pump(tester, {'reg': overdueOnHose()});
    expect(
      find.text('Necklace hose: Hose replacement overdue'),
      findsOneWidget,
    );
    expect(find.textContaining('Overdue since'), findsOneWidget);
  });

  testWidgets('the header stays calm when nothing in the subtree is due', (
    tester,
  ) async {
    await pump(tester, const {});
    expect(find.textContaining('Hose replacement'), findsNothing);
    expect(find.byIcon(Icons.warning), findsNothing);
  });

  testWidgets('a due-soon clock gets a banner too', (tester) async {
    await pump(tester, {
      'reg': (
        ownerId: 'reg',
        ownerName: 'Cold water reg',
        status: hoseSwap(
          equipmentId: 'reg',
          severity: ServiceClockSeverity.dueSoon,
          dueDate: DateTime(2026, 7, 13),
        ),
      ),
    });
    expect(find.text('Hose replacement due in 12d'), findsOneWidget);
  });

  testWidgets('retired gear keeps its warning from its own clocks', (
    tester,
  ) async {
    // A retired item is absent from the active rollup, so the header must
    // fall back to the item's own clocks or the warning would vanish.
    await pump(tester, const {}, own: [hoseSwap(equipmentId: 'reg')]);
    expect(find.text('Hose replacement overdue'), findsOneWidget);
  });

  testWidgets('the split view shows the named banner exactly once', (
    tester,
  ) async {
    // Embedded mode renders its thin strip AND the page body beneath it,
    // and the body carries this banner. A status line in the strip as well
    // would show and announce the same thing twice.
    await pump(tester, {'reg': overdueOnHose()}, embedded: true);
    expect(
      find.text('Necklace hose: Hose replacement overdue'),
      findsOneWidget,
    );
  });
}
