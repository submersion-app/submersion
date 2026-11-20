import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_status_lights.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _overdue = GearSeverityGroup(
  count: 1,
  worst: GearGauge(
    type: EquipmentType.regulator,
    itemId: 'reg-1',
    itemName: 'Regulator',
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's',
        equipmentId: 'reg-1',
        serviceKindId: 'k',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      kind: ServiceKind(
        id: 'k',
        name: 'Annual',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      anchor: DateTime(2025),
      dueDate: DateTime(2026),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 9),
    ),
  ),
);

/// Builds the lights for [gauges] inside a real widget tree, the way the
/// header does, and returns them.
Future<List<HomeStatusLight>> _lights(
  WidgetTester tester,
  DashboardGauges gauges, {
  Set<String> hidden = const {},
}) async {
  late List<HomeStatusLight> out;
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            out = buildHomeStatusLights(context, ref, gauges, hidden);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return out;
}

void main() {
  testWidgets('every light knows its chip type and has an action', (
    tester,
  ) async {
    final lights = await _lights(
      tester,
      DashboardGauges(
        gearOverdue: _overdue,
        hasGear: true,
        insurance: null,
        noFlyStatus: null,
        daysSinceLastDive: 3,
      ),
    );
    expect(lights.map((l) => l.type), contains(HomeChipType.gear));
    expect(lights.map((l) => l.type), contains(HomeChipType.lastDive));
    for (final l in lights) {
      expect(l.label, isNotEmpty);
    }
  });

  testWidgets('safety lights survive their chip being hidden', (tester) async {
    final lights = await _lights(
      tester,
      DashboardGauges(
        gearOverdue: _overdue,
        hasGear: true,
        insurance: DiverInsurance(provider: 'DAN', expiryDate: DateTime(2020)),
        noFlyStatus: null,
        daysSinceLastDive: null,
      ),
      hidden: {for (final t in HomeChipType.values) t.name},
    );
    expect(lights.map((l) => l.type).toSet(), {
      HomeChipType.gear,
      HomeChipType.insurance,
    });
    expect(lights.every((l) => l.safety), isTrue);
  });

  testWidgets('hiding a chip removes its light', (tester) async {
    const gauges = DashboardGauges(
      hasGear: true,
      insurance: null,
      noFlyStatus: null,
      daysSinceLastDive: 3,
    );
    final shown = await _lights(tester, gauges);
    final hidden = await _lights(tester, gauges, hidden: {'lastDive'});
    expect(shown.map((l) => l.type), contains(HomeChipType.lastDive));
    expect(hidden.map((l) => l.type), isNot(contains(HomeChipType.lastDive)));
    expect(shown.where((l) => l.safety), isEmpty);
  });

  test('ordering puts alerts, then warnings, then the rest in order', () {
    HomeStatusLight light(HomeChipType type, HomeLightTone tone) =>
        HomeStatusLight(
          type: type,
          tone: tone,
          label: type.name,
          icon: Icons.circle,
          onTap: () {},
        );
    final ordered = orderLightsBySeverity([
      light(HomeChipType.insurance, HomeLightTone.ok),
      light(HomeChipType.backup, HomeLightTone.warn),
      light(HomeChipType.lastDive, HomeLightTone.neutral),
      light(HomeChipType.gear, HomeLightTone.alert),
      light(HomeChipType.sync, HomeLightTone.warn),
    ]);
    expect(ordered.map((l) => l.type), [
      HomeChipType.gear,
      HomeChipType.backup,
      HomeChipType.sync,
      HomeChipType.insurance,
      HomeChipType.lastDive,
    ]);
  });

  test('the phone split names warnings and alerts and counts the rest', () {
    HomeStatusLight light(HomeLightTone tone) => HomeStatusLight(
      type: HomeChipType.backup,
      tone: tone,
      label: 'x',
      icon: Icons.circle,
      onTap: () {},
    );
    final split = splitForPhone([
      light(HomeLightTone.ok),
      light(HomeLightTone.alert),
      light(HomeLightTone.neutral),
      light(HomeLightTone.warn),
    ]);
    expect(split.attention.map((l) => l.tone), [
      HomeLightTone.alert,
      HomeLightTone.warn,
    ]);
    expect(split.clear, 2);
    expect(splitForPhone([light(HomeLightTone.ok)]).attention, isEmpty);
  });
}
