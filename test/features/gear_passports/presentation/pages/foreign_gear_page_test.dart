import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/gear_passports/data/services/gear_adoption_service.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/presentation/pages/foreign_gear_page.dart';
import 'package:submersion/features/gear_passports/presentation/providers/gear_passport_providers.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

class _BrokenEquipment extends EquipmentRepository {
  @override
  Future<EquipmentItem?> getEquipmentById(String id) async =>
      throw StateError('database is locked');
}

class _FakeAdoption extends GearAdoptionService {
  _FakeAdoption({this.held = false});

  final bool held;
  final adopted = <(GearTagPayload, String)>[];

  @override
  Future<EquipmentItem> adopt(
    GearTagPayload tag, {
    required String? diverId,
    required String fallbackName,
    DateTime? now,
  }) async {
    if (held) throw const PassportIdInUse('held');
    adopted.add((tag, fallbackName));
    return const EquipmentItem(
      id: 'new',
      name: 'Club reg 4',
      type: EquipmentType.regulator,
    );
  }
}

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

  final tag = GearTagPayload(
    passportId: pid,
    typeCode: 'regulator',
    writtenOn: DateTime(2026, 10, 1),
    name: 'Club reg 4',
    brand: 'Scubapro',
    model: 'MK25',
    serial: 'SP-4',
    lastService: DateTime(2026, 2, 14),
  );

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required String location,
    required _FakeAdoption adoption,
    List<dynamic> extraOverrides = const [],
  }) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/equipment/gear-tag',
          builder: (context, state) =>
              ForeignGearPage.fromQuery(state.uri.queryParameters['t']),
        ),
        GoRoute(
          path: '/equipment/:id/gear-passport',
          builder: (context, state) =>
              Text('gear passport ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          gearAdoptionServiceProvider.overrideWithValue(adoption),
          ...extraOverrides,
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
    return AppLocalizations.of(tester.element(find.byType(Scaffold)));
  }

  testWidgets('shows what the tag says', (tester) async {
    final l10n = await pump(
      tester,
      location: foreignGearLocation(tag),
      adoption: _FakeAdoption(),
    );
    String date(DateTime d) => DateFormat.yMMMd('en_US').format(d);
    expect(find.text('Club reg 4'), findsOneWidget);
    expect(
      find.text(EquipmentType.regulator.localizedName(l10n)),
      findsOneWidget,
    );
    expect(find.text('Scubapro MK25'), findsOneWidget);
    expect(find.text(l10n.passport_foreign_serial('SP-4')), findsOneWidget);
    expect(
      find.text(l10n.gearPassport_entry_lastService(date(tag.lastService!))),
      findsOneWidget,
    );
    expect(
      find.text(l10n.passport_foreign_writtenOn(date(tag.writtenOn!))),
      findsOneWidget,
    );
    expect(find.text(l10n.passport_scan_newerFormat), findsNothing);
  });

  testWidgets('an unknown type is plain gear and says it is newer', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      location: Uri(
        path: '/equipment/gear-tag',
        queryParameters: {'t': 'https://submersion.app/g#f=2&p=$pid&t=jetpack'},
      ).toString(),
      adoption: _FakeAdoption(),
    );
    expect(find.text(l10n.gearPassport_unknownType), findsNWidgets(2));
    expect(find.text(l10n.passport_scan_newerFormat), findsOneWidget);
  });

  testWidgets('Add to my gear adopts the tag and opens the item', (
    tester,
  ) async {
    final adoption = _FakeAdoption();
    final l10n = await pump(
      tester,
      location: foreignGearLocation(tag),
      adoption: adoption,
    );
    await tester.tap(find.text(l10n.passport_foreign_addToGear));
    await tester.pumpAndSettle();
    expect(adoption.adopted.single.$1, tag);
    expect(
      adoption.adopted.single.$2,
      EquipmentType.regulator.localizedName(l10n),
    );
    expect(find.text('gear passport new'), findsOneWidget);
  });

  testWidgets('a held id names the item that holds it', (tester) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await tester.runAsync(
      () => db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'held',
              name: 'Held reg',
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
            ),
          ),
    );
    final l10n = await pump(
      tester,
      location: foreignGearLocation(tag),
      adoption: _FakeAdoption(held: true),
    );
    await tester.tap(find.text(l10n.passport_foreign_addToGear));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_tag_linkInUse('Held reg')), findsOneWidget);
  });

  testWidgets('a held id still says so when the holder cannot be read', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      location: foreignGearLocation(tag),
      adoption: _FakeAdoption(held: true),
      extraOverrides: [
        equipmentRepositoryProvider.overrideWithValue(_BrokenEquipment()),
      ],
    );
    await tester.tap(find.text(l10n.passport_foreign_addToGear));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.passport_tag_linkInUse('held')), findsOneWidget);
    final add = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(l10n.passport_foreign_addToGear),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(add.onPressed, isNotNull);
  });

  testWidgets('a broken link says so and offers nothing', (tester) async {
    final l10n = await pump(
      tester,
      location: '/equipment/gear-tag?t=nope',
      adoption: _FakeAdoption(),
    );
    expect(find.text(l10n.gearPassport_tag_linkInvalid), findsOneWidget);
    expect(find.text(l10n.passport_foreign_addToGear), findsNothing);
  });
}
