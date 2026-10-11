import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_trip_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/presentation/pages/gear_passport_page.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

const regulator = EquipmentItem(
  id: 'reg',
  name: 'Primary',
  type: EquipmentType.regulator,
  brand: 'Apeks',
  model: 'XTX50',
  serialNumber: 'AB12345',
);

const tank = EquipmentItem(
  id: 'tank',
  name: 'Faber 12',
  type: EquipmentType.tank,
);

ServiceRecord record(DateTime date) => ServiceRecord(
  id: 'r${date.millisecondsSinceEpoch}',
  equipmentId: 'reg',
  serviceCategory: ServiceCategory.annual,
  serviceDate: date,
  createdAt: date,
  updatedAt: date,
);

void main() {
  late String? savedLocale;
  setUp(() async {
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
  });
  tearDown(() async {
    Intl.defaultLocale = savedLocale;
    await tearDownTestDatabase();
  });

  Future<AppLocalizations> pump(
    WidgetTester tester,
    EquipmentItem item, {
    required List<ServiceRecord> records,
    GearTagPayload? scanned,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 4000);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: gearPassportLocation(item.id),
      initialExtra: scanned,
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) => const Text('detail'),
          routes: [
            GoRoute(
              path: 'gear-passport',
              builder: (context, state) => GearPassportPage(
                equipmentId: state.pathParameters['id']!,
                scannedTag: scannedGearTagFrom(state.extra),
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          equipmentItemProvider(item.id).overrideWith((ref) async => item),
          passportIdProvider(item.id).overrideWith((ref) async => pid),
          serviceRecordsForEquipmentProvider(
            item.id,
          ).overrideWith((ref) async => records),
          serviceClockStatusesProvider(item.id).overrideWith((ref) async => []),
          nfcSupportProvider.overrideWith(
            (ref) async => NfcSupport.unsupported,
          ),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  }

  testWidgets('shows the header, cards and tag for a regulator', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      regulator,
      records: [record(DateTime(2026, 3, 2))],
    );
    expect(find.text(l10n.gearPassport_title), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Apeks XTX50'), findsOneWidget);
    expect(find.text(l10n.gearPassport_recent_title), findsOneWidget);
    expect(find.text(l10n.passport_tag_title), findsOneWidget);
    expect(find.byType(PassportQrView), findsOneWidget);
    expect(find.byType(ServiceClocksCard), findsOneWidget);
    expect(find.byType(ExposureCard), findsOneWidget);
    expect(find.byType(EquipmentLocationCard), findsOneWidget);
    expect(find.byType(PassportTripCard), findsOneWidget);
  });

  testWidgets('no service yet says so', (tester) async {
    final l10n = await pump(tester, regulator, records: const []);
    expect(find.text(l10n.gearPassport_recent_none), findsOneWidget);
  });

  testWidgets('a scanned tag older than the newest service is stale', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      regulator,
      records: [record(DateTime(2026, 10, 11))],
      scanned: GearTagPayload(
        passportId: pid,
        typeCode: 'regulator',
        writtenOn: DateTime(2026, 10, 1),
        name: 'Primary',
      ),
    );
    expect(find.text(l10n.passport_tag_stale), findsOneWidget);
  });

  testWidgets('a current scanned tag is not stale', (tester) async {
    final l10n = await pump(
      tester,
      regulator,
      records: [record(DateTime(2026, 3, 2))],
      scanned: GearTagPayload(
        passportId: pid,
        typeCode: 'regulator',
        writtenOn: DateTime(2026, 10, 1),
        name: 'Primary',
      ),
    );
    expect(find.text(l10n.passport_tag_stale), findsNothing);
  });

  testWidgets('a wanted item has no tag card', (tester) async {
    final l10n = await pump(
      tester,
      regulator.copyWith(status: EquipmentStatus.wanted),
      records: const [],
    );
    expect(find.text(l10n.passport_tag_title), findsNothing);
  });

  testWidgets('a tank id shows the cylinder passport', (tester) async {
    await pump(tester, tank, records: const []);
    expect(find.byType(PassportPage), findsOneWidget);
  });

  testWidgets('recent service lists at most three, newest first', (
    tester,
  ) async {
    await pump(
      tester,
      regulator,
      records: [for (var m = 1; m <= 5; m++) record(DateTime(2026, m, 1))],
    );
    final rows = find.descendant(
      of: find.byKey(const Key('gearRecentService_rows')),
      matching: find.byType(ListTile),
    );
    expect(rows, findsNWidgets(3));
    final first = tester.widget<ListTile>(rows.first);
    expect(
      (first.subtitle! as Text).data,
      startsWith(DateFormat.yMMMd('en_US').format(DateTime(2026, 5, 1))),
    );
  });
}
