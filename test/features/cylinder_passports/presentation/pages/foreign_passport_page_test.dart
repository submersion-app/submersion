import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Club 10',
    serial: 'AB12345',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  Future<AppLocalizations> pump(
    WidgetTester tester,
    CylinderPassportPayload? tag, {
    MockSettingsNotifier? settings,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: ForeignPassportPage(tag: tag),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(ForeignPassportPage)),
    );
  }

  testWidgets('shows the snapshot the tag carries', (tester) async {
    final l10n = await pump(tester, full);
    expect(find.text('Club 10'), findsOneWidget);
    expect(find.text(l10n.passport_foreign_serial('AB12345')), findsOneWidget);
    expect(find.text(l10n.passport_foreign_notInGear), findsOneWidget);
    expect(find.text('10 L'), findsOneWidget);
    expect(find.text('300 bar'), findsOneWidget);
    expect(find.text('Steel'), findsOneWidget);
    expect(find.text(l10n.passport_foreign_o2Clean), findsOneWidget);
    expect(find.textContaining('2024'), findsWidgets);
    expect(find.text(l10n.passport_foreign_noDetails), findsNothing);
  });

  const al80 = CylinderPassportPayload(
    passportId: id,
    volumeL: 11.1,
    workingPressureBar: 207,
  );

  testWidgets('tank volume keeps its decimal in liters', (tester) async {
    await pump(tester, al80);
    expect(find.text('11.1 L'), findsOneWidget);
  });

  testWidgets('tank volume reads as rated gas capacity in cubic feet', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await settings.setVolumeUnit(VolumeUnit.cubicFeet);
    await pump(tester, al80, settings: settings);
    final rated = TankPresets.matchBySpecs(11.1, 207)!.ratedCapacityCuft!;
    expect(find.text('${rated.round()} cuft'), findsOneWidget);
  });

  testWidgets('an identity-only tag says it carries no details', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      CylinderPassportPayload(passportId: id, writtenOn: DateTime(2026, 9, 25)),
    );
    expect(find.text(l10n.passport_foreign_defaultName), findsOneWidget);
    expect(find.text(l10n.passport_foreign_noDetails), findsOneWidget);
  });

  testWidgets('a newer format is noted', (tester) async {
    final l10n = await pump(
      tester,
      const CylinderPassportPayload(passportId: id, formatVersion: 2),
    );
    expect(find.text(l10n.passport_scan_newerFormat), findsOneWidget);
  });

  testWidgets('a route with no readable tag says so', (tester) async {
    final l10n = await pump(tester, null);
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
  });

  test('the location round trips the tag', () {
    final location = foreignPassportLocation(full);
    expect(location, startsWith('/equipment/tag?t='));
    final t = Uri.parse(location).queryParameters['t'];
    expect(foreignTagFromQuery(t), full);
    expect(foreignTagFromQuery(null), isNull);
    expect(foreignTagFromQuery('nonsense'), isNull);
  });

  testWidgets('Use on a dive opens a new dive with the cylinder', (
    tester,
  ) async {
    Object? extra;
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: foreignPassportLocation(full),
      routes: [
        GoRoute(
          path: '/equipment/tag',
          builder: (context, state) => ForeignPassportPage(
            tag: foreignTagFromQuery(state.uri.queryParameters['t']),
          ),
        ),
        GoRoute(
          path: '/dives/new',
          builder: (context, state) {
            extra = state.extra;
            return const Text('new dive');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('foreign_useOnDive')));
    await tester.pumpAndSettle();
    expect(find.text('new dive'), findsOneWidget);
    final tank = (extra! as DivePrefill).tank!;
    expect(tank.volume, 10);
    expect(tank.workingPressure, 300);
  });

  testWidgets('Add to my gear creates the cylinder and opens its passport', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: foreignPassportLocation(full),
      routes: [
        GoRoute(
          path: '/equipment/tag',
          builder: (context, state) => ForeignPassportPage(
            tag: foreignTagFromQuery(state.uri.queryParameters['t']),
          ),
        ),
        GoRoute(
          path: '/equipment/:id/passport',
          builder: (context, state) =>
              Text('passport ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('foreign_addToGear')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('passport '), findsOneWidget);
  });
}
