import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, EquipmentCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/gear_passports/presentation/pages/gear_passport_page.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_passport_entry_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _regulator = EquipmentItem(
  id: 'reg',
  name: 'Primary',
  type: EquipmentType.regulator,
);

/// The gear passport's minting, loading and error states, its entry card,
/// and the shared Log service dialog (issue #2652).
void main() {
  late AppDatabase db;
  late String? savedLocale;

  setUp(() async {
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    Intl.defaultLocale = savedLocale;
    await tearDownTestDatabase();
  });

  Future<void> seed(WidgetTester tester, {String status = 'active'}) =>
      tester.runAsync(() async {
        final t = DateTime.now().millisecondsSinceEpoch;
        await db
            .into(db.equipment)
            .insert(
              EquipmentCompanion.insert(
                id: 'reg',
                name: 'Primary',
                type: 'regulator',
                status: Value(status),
                createdAt: t,
                updatedAt: t,
              ),
            );
      });

  Future<AppLocalizations> pumpPage(
    WidgetTester tester, {
    required FutureOr<EquipmentItem?> Function() item,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 4000);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: gearPassportLocation('reg'),
      routes: [
        GoRoute(
          path: '/equipment/:id/gear-passport',
          builder: (context, state) =>
              GearPassportPage(equipmentId: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          equipmentItemProvider('reg').overrideWith((ref) async => item()),
          serviceRecordsForEquipmentProvider(
            'reg',
          ).overrideWith((ref) async => const <ServiceRecord>[]),
          serviceClockStatusesProvider('reg').overrideWith((ref) async => []),
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
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  }

  Future<String?> passportIdOf(WidgetTester tester) => tester
      .runAsync(() => CylinderPassportRepository().getPassportId('reg'))
      .then((id) => id);

  testWidgets('opening the passport mints the item its id', (tester) async {
    await seed(tester);
    await pumpPage(tester, item: () => _regulator);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(
      await passportIdOf(tester),
      const Uuid().v5(kCylinderPassportNamespace, 'reg'),
    );
  });

  testWidgets('a wanted item is never minted', (tester) async {
    await seed(tester, status: 'wanted');
    await pumpPage(
      tester,
      item: () => _regulator.copyWith(status: EquipmentStatus.wanted),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(await passportIdOf(tester), isNull);
  });

  testWidgets('a missing item shows an empty page', (tester) async {
    final l10n = await pumpPage(tester, item: () => null);
    await tester.pumpAndSettle();
    expect(find.text(l10n.gearPassport_title), findsOneWidget);
    expect(find.text(l10n.passport_tag_title), findsNothing);
  });

  testWidgets('loading shows a spinner under the title', (tester) async {
    final pending = Completer<EquipmentItem?>();
    final l10n = await pumpPage(tester, item: () => pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.gearPassport_title), findsOneWidget);
    pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('a failed load shows the error', (tester) async {
    await pumpPage(
      tester,
      item: () => Future<EquipmentItem?>.error(StateError('locked')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('locked'), findsOneWidget);
  });

  group('entry card', () {
    Future<List<String>> pumpCard(
      WidgetTester tester, {
      required String? passportId,
      required List<ServiceRecord> records,
    }) async {
      final pushed = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: GearPassportEntryCard(equipment: _regulator),
            ),
          ),
          GoRoute(
            path: '/equipment/:id/gear-passport',
            builder: (context, state) {
              pushed.add(state.uri.path);
              return const Scaffold(body: Text('passport'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            passportIdProvider('reg').overrideWith((ref) async => passportId),
            serviceRecordsForEquipmentProvider(
              'reg',
            ).overrideWith((ref) async => records),
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
      return pushed;
    }

    testWidgets('shows the QR and the last service, and opens the passport', (
      tester,
    ) async {
      final serviced = DateTime(2026, 3, 2);
      final pushed = await pumpCard(
        tester,
        passportId: '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
        records: [
          ServiceRecord(
            id: 'r1',
            equipmentId: 'reg',
            serviceCategory: ServiceCategory.annual,
            serviceDate: serviced,
            createdAt: serviced,
            updatedAt: serviced,
          ),
        ],
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GearPassportEntryCard)),
      );
      expect(find.byType(PassportQrView), findsOneWidget);
      expect(
        find.text(
          l10n.gearPassport_entry_lastService(
            DateFormat.yMMMd('en_US').format(serviced),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.passport_open));
      await tester.pumpAndSettle();
      expect(pushed, ['/equipment/reg/gear-passport']);
    });

    testWidgets('before an id exists it shows a placeholder icon', (
      tester,
    ) async {
      await pumpCard(tester, passportId: null, records: const []);
      expect(find.byType(PassportQrView), findsNothing);
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
    });
  });

  testWidgets('Log service opens the service record dialog for the kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: (await getBaseOverrides()).cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showLogServiceDialog(
                  context,
                  ref,
                  equipmentId: 'reg',
                  serviceKindId: 'annual-service',
                ),
                child: const Text('log'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('log'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<ServiceRecordDialog>(
      find.byType(ServiceRecordDialog),
    );
    expect(dialog.equipmentId, 'reg');
    expect(dialog.serviceKindId, 'annual-service');
  });
}
