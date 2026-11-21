import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_header_bar.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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

final _quietGauges = DashboardGauges(
  hasGear: true,
  insurance: DiverInsurance(provider: 'DAN', expiryDate: DateTime(2099)),
  noFlyStatus: null,
  daysSinceLastDive: 3,
  lastBackupTime: DateTime.now(),
);

Diver _diver(String name) => Diver(
  id: 'me',
  name: name,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

int _gaugeBuilds = 0;

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  int divers = 1,
  String name = 'Eric',
  Future<DashboardGauges> Function()? gauges,
  Locale locale = const Locale('en'),
  double textScale = 1,
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
        builder: (_, _) => const Scaffold(
          body: Column(children: [HomeHeaderBar(), HomeStatusStrip()]),
        ),
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
        diverCountProvider.overrideWith((ref) async => divers),
        dashboardDiverProvider.overrideWith((ref) async => _diver(name)),
      ].cast(),
      child: MaterialApp.router(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
  testWidgets('no switcher with one diver', (tester) async {
    await _pump(tester, width: 1280);
    expect(find.byKey(HomeHeaderBar.switcherKey), findsNothing);
    expect(find.text('Submersion'), findsOneWidget);
  });

  testWidgets('a switcher with two divers', (tester) async {
    await _pump(tester, width: 1280, divers: 2);
    expect(find.byKey(HomeHeaderBar.switcherKey), findsOneWidget);
    expect(find.byTooltip('Switch Diver'), findsOneWidget);
  });

  testWidgets('desktop shows Log dive, Plan and the lights', (tester) async {
    await _pump(tester, width: 1280);
    expect(find.text('Log Dive'), findsOneWidget);
    expect(find.text('Plan Dive'), findsOneWidget);
    expect(find.text('Insurance OK'), findsOneWidget);
    expect(find.byType(HomeStatusStrip), findsOneWidget);
    // The phone strip renders nothing at desktop width.
    expect(find.textContaining('all clear'), findsNothing);
  });

  testWidgets('every control in the header has an action', (tester) async {
    await _pump(tester, width: 1280, divers: 2);
    final wells = tester.widgetList<InkWell>(
      find.descendant(
        of: find.byType(HomeHeaderBar),
        matching: find.byType(InkWell),
      ),
    );
    expect(wells, isNotEmpty);
    for (final w in wells) {
      expect(w.onTap, isNotNull);
    }
  });

  testWidgets('phone: a warning is named and the rest are counted', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    expect(find.textContaining('Backup'), findsOneWidget);
    expect(find.text('3 all clear'), findsOneWidget);
    expect(find.text('Insurance OK'), findsNothing);
  });

  testWidgets('phone: nothing amber or red shows one All clear pill', (
    tester,
  ) async {
    await _pump(tester, width: 390, gauges: () async => _quietGauges);
    expect(find.text('All clear'), findsOneWidget);
  });

  testWidgets('phone: the count pill opens every light', (tester) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('3 all clear'));
    await tester.pumpAndSettle();
    expect(find.text('Insurance OK'), findsOneWidget);
  });

  testWidgets('phone: More holds Plan and the emergency card', (tester) async {
    await _pump(tester, width: 390);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Plan Dive'), findsOneWidget);
    expect(find.text('Emergency card'), findsOneWidget);
  });

  testWidgets('a long diver name does not overflow the bar at 800 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 800,
      divers: 2,
      name: 'Bartholomew Maximilian Featherstonehaugh-Cholmondeley',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gauges error shows a retry that refetches', (tester) async {
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

  testWidgets('phone: every button is at least 44 by 44', (tester) async {
    await _pump(tester, width: 390, divers: 2);
    for (final finder in [
      find.byTooltip('Log Dive'),
      find.byTooltip('More'),
      find.byKey(HomeHeaderBar.switcherKey),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(44), reason: '$finder');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$finder');
    }
  });

  testWidgets('German at text scale 2 fits the bar at 800 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 800,
      divers: 2,
      locale: const Locale('de'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: with every light hidden the strip claims nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 390,
      gauges: () async => const DashboardGauges(
        hasGear: true,
        insurance: null,
        noFlyStatus: null,
        daysSinceLastDive: null,
      ),
      hiddenChips: {for (final t in HomeChipType.values) t.name},
    );
    expect(find.text('All clear'), findsNothing);
    // No empty, bordered bar is left behind under the header.
    expect(tester.getSize(find.byType(HomeStatusStrip)).height, 0);
  });

  testWidgets('phone: no empty strip while the lights load', (tester) async {
    final never = Completer<DashboardGauges>();
    await _pump(tester, width: 390, gauges: () => never.future);
    expect(tester.getSize(find.byType(HomeStatusStrip)).height, 0);
  });

  testWidgets('phone: the sheet lists warnings before quiet lights', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('3 all clear'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final backup = tester.getTopLeft(
      find.descendant(of: sheet, matching: find.textContaining('Backup')),
    );
    final insurance = tester.getTopLeft(
      find.descendant(of: sheet, matching: find.text('Insurance OK')),
    );
    expect(
      backup.dy < insurance.dy ||
          (backup.dy == insurance.dy && backup.dx < insurance.dx),
      isTrue,
    );
  });
}
