import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_entry_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late String? savedIntlLocale;
  setUp(() async {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntlLocale;
    await tearDownTestDatabase();
  });

  Future<AppLocalizations> pump(
    WidgetTester tester,
    EquipmentItem item, {
    CylinderFill? newest,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 3000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/equipment/${item.id}',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              EquipmentDetailPage(equipmentId: item.id),
          routes: [
            GoRoute(
              path: 'passport',
              builder: (context, state) => const Text('passport route'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(item.id).overrideWith((ref) async => item),
          equipmentDiveCountProvider(item.id).overrideWith((ref) async => 0),
          passportIdProvider(item.id).overrideWith((ref) async => null),
          newestFillProvider(item.id).overrideWith((ref) async => newest),
          serviceClockStatusesProvider(item.id).overrideWith((ref) async => []),
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
    return AppLocalizations.of(
      tester.element(find.byType(EquipmentDetailPage)),
    );
  }

  testWidgets('a cylinder shows the passport entry card', (tester) async {
    final l10n = await pump(
      tester,
      const EquipmentItem(
        id: 'tank',
        name: 'Faber 12',
        type: EquipmentType.tank,
      ),
    );
    expect(find.byType(PassportEntryCard), findsOneWidget);
    expect(find.text(l10n.passport_open), findsOneWidget);
    expect(find.text(l10n.passport_entry_noFill), findsOneWidget);
  });

  testWidgets('a regulator does not', (tester) async {
    await pump(
      tester,
      const EquipmentItem(
        id: 'reg',
        name: 'Apeks',
        type: EquipmentType.regulator,
      ),
    );
    expect(find.byType(PassportEntryCard), findsNothing);
  });

  testWidgets('shows the newest fill and opens the passport', (tester) async {
    final t = DateTime(2026, 9, 20);
    final l10n = await pump(
      tester,
      const EquipmentItem(
        id: 'tank',
        name: 'Faber 12',
        type: EquipmentType.tank,
      ),
      newest: CylinderFill(
        id: 'f1',
        passportId: 'pp',
        equipmentId: 'tank',
        filledAt: t,
        o2Percent: 32,
        pressureBar: 220,
        createdAt: t,
        updatedAt: t,
      ),
    );
    expect(find.textContaining('EAN32'), findsOneWidget);
    expect(find.textContaining('220 bar'), findsOneWidget);

    await tester.tap(find.text(l10n.passport_open));
    await tester.pumpAndSettle();
    expect(find.text('passport route'), findsOneWidget);
  });

  testWidgets('a fill logged without a pressure leaves it out', (tester) async {
    final t = DateTime(2026, 9, 20);
    await pump(
      tester,
      const EquipmentItem(
        id: 'tank',
        name: 'Faber 12',
        type: EquipmentType.tank,
      ),
      newest: CylinderFill(
        id: 'f1',
        passportId: 'pp',
        equipmentId: 'tank',
        filledAt: t,
        o2Percent: 32,
        createdAt: t,
        updatedAt: t,
      ),
    );
    expect(find.textContaining('EAN32'), findsOneWidget);
    expect(find.textContaining('--'), findsNothing);
  });
}
