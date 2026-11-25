import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_banner_row.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_header_bar.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_light_chip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_status_lights.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Backup age warns, last dive is quiet, insurance and no-fly are fine.
final _mixedGauges = DashboardGauges(
  hasGear: true,
  insurance: DiverInsurance(provider: 'DAN', expiryDate: DateTime(2099)),
  noFlyStatus: null,
  daysSinceLastDive: 3,
  lastBackupTime: DateTime.now().subtract(const Duration(days: 10)),
);

final _overdueGear = GearSeverityGroup(
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

final _plus = find.byKey(HomeHeaderBar.quickActionsKey);

int _gaugeBuilds = 0;

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  Future<DashboardGauges> Function()? gauges,
  Set<String> hiddenChips = const {},
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _gaugeBuilds = 0;
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(
      AppSettings(hiddenHomeChips: hiddenChips),
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Column(children: [HomeBannerRow()])),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        dashboardGaugesProvider.overrideWith((ref) {
          _gaugeBuilds++;
          return (gauges ?? () async => _mixedGauges)();
        }),
      ].cast(),
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('the + menu opens the quick actions at $width wide', (
      tester,
    ) async {
      await _pump(tester, width: width);
      expect(tester.getSize(_plus).height, greaterThanOrEqualTo(44));
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      expect(find.text('Log Dive'), findsOneWidget);
      expect(find.text('Plan Dive'), findsOneWidget);
      expect(find.text('Emergency card'), findsOneWidget);
    });
  }

  testWidgets('the row is as tall as the compact bar', (tester) async {
    await _pump(tester, width: 1280);
    expect(
      tester.getSize(find.byType(HomeBannerRow)).height,
      HomeHeaderBar.barHeight,
    );
  });

  testWidgets('wider screens show every light', (tester) async {
    await _pump(tester, width: 1280);
    expect(find.text('Insurance OK'), findsOneWidget);
    expect(find.textContaining('Backup'), findsOneWidget);
    expect(find.textContaining('all clear'), findsNothing);
  });

  testWidgets('phone names a warning and counts the rest', (tester) async {
    await _pump(tester, width: 390);
    expect(find.textContaining('Backup'), findsOneWidget);
    expect(find.text('3 all clear'), findsOneWidget);
    expect(find.text('Insurance OK'), findsNothing);
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('an overdue gear light shows while hidden at $width wide', (
      tester,
    ) async {
      await _pump(
        tester,
        width: width,
        hiddenChips: {for (final t in HomeChipType.values) t.name},
        gauges: () async => DashboardGauges(
          gearOverdue: _overdueGear,
          hasGear: true,
          insurance: null,
          noFlyStatus: null,
          daysSinceLastDive: 3,
        ),
      );
      final chips = tester.widgetList<HomeLightChip>(
        find.byType(HomeLightChip),
      );
      expect(chips.map((c) => c.light.type), contains(HomeChipType.gear));
    });
  }

  testWidgets('banner row shows retry chip on gauge error', (tester) async {
    await _pump(
      tester,
      width: 1280,
      gauges: () async => throw StateError('boom'),
    );
    final before = _gaugeBuilds;
    await tester.tap(find.text('Status unavailable - tap to retry'));
    await tester.pump();
    await tester.pump();
    expect(_gaugeBuilds, greaterThan(before));
  });

  testWidgets('the delegate pins the row at the bar height', (tester) async {
    const delegate = HomeBannerRowDelegate();
    expect(delegate.minExtent, HomeHeaderBar.barHeight);
    expect(delegate.maxExtent, HomeHeaderBar.barHeight);
  });
}
