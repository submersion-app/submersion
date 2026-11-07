import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_card.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

EquipmentItem cylinder(
  String id, {
  double workingPressureBar = 232,
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(
  id: id,
  name: 'Double 12 $id',
  type: EquipmentType.tank,
  status: status,
  attributes: [
    EquipmentAttribute(
      id: '$id-v',
      equipmentId: id,
      key: EquipmentAttrKeys.volumeL,
      valueNum: 12,
    ),
    EquipmentAttribute(
      id: '$id-wp',
      equipmentId: id,
      key: EquipmentAttrKeys.workingPressureBar,
      valueNum: workingPressureBar,
    ),
  ],
);

CylinderPairing pairing(
  String id,
  String a,
  String b,
  DateTime on, [
  DateTime? off,
]) => CylinderPairing(
  id: id,
  cylinderAId: a,
  cylinderBId: b,
  pairedOn: on,
  unpairedOn: off,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// Records what the flow asked of the repository, and throws a clash for
/// the first create when [clashOnce] is set.
class FakePairingRepository extends CylinderPairingRepository {
  FakePairingRepository({this.clashOnce});

  final List<CylinderPairing>? clashOnce;
  final creates = <({String a, String b, DateTime on, bool replace})>[];
  final ends = <({String id, DateTime end})>[];
  final deletes = <String>[];

  @override
  Future<CylinderPairing> createPairing({
    required String cylinderAId,
    required String cylinderBId,
    required DateTime pairedOn,
    bool replace = false,
  }) async {
    creates.add((
      a: cylinderAId,
      b: cylinderBId,
      on: pairedOn,
      replace: replace,
    ));
    if (clashOnce != null && !replace) throw PairingClash(clashOnce!);
    return pairing('new', cylinderAId, cylinderBId, calendarDay(pairedOn));
  }

  @override
  Future<void> endPairing(String id, DateTime unpairedOn) async =>
      ends.add((id: id, end: unpairedOn));

  @override
  Future<void> deletePairing(String id) async => deletes.add(id);
}

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
    WidgetTester tester, {
    required List<EquipmentItem> gear,
    List<CylinderPairing> pairings = const [],
    FakePairingRepository? repository,
    AppSettings? settings,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides(
      settingsNotifier: settings == null
          ? null
          : MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          for (final item in gear)
            equipmentItemProvider(item.id).overrideWith((ref) async => item),
          activeEquipmentProvider.overrideWith((ref) async => gear),
          allPairingsProvider.overrideWith((ref) async => pairings),
          cylinderPairingRepositoryProvider.overrideWithValue(
            repository ?? FakePairingRepository(),
          ),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: TwinSetCard(equipmentId: 'A')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TwinSetCard)));
  }

  testWidgets('an unlinked cylinder offers a link', (tester) async {
    final l10n = await pump(tester, gear: [cylinder('A'), cylinder('B')]);
    expect(find.text(l10n.twinSet_title), findsOneWidget);
    expect(find.text(l10n.twinSet_none), findsOneWidget);
    expect(find.text(l10n.twinSet_link), findsOneWidget);
    expect(find.text(l10n.twinSet_unlink), findsNothing);
  });

  testWidgets('a linked cylinder shows its partner and since date', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      gear: [cylinder('A'), cylinder('B')],
      pairings: [pairing('p', 'B', 'A', DateTime.utc(2026, 3, 3))],
    );
    expect(find.text('Double 12 B'), findsOneWidget);
    expect(find.textContaining(l10n.twinSet_since('')), findsOneWidget);
    expect(find.textContaining('2026'), findsWidgets);
    expect(find.text(l10n.twinSet_replace), findsOneWidget);
    expect(find.text(l10n.twinSet_unlink), findsOneWidget);
    expect(find.text(l10n.twinSet_link), findsNothing);
  });

  testWidgets('a sold partner shows its status', (tester) async {
    final l10n = await pump(
      tester,
      gear: [
        cylinder('A'),
        cylinder('B', status: EquipmentStatus.sold),
      ],
      pairings: [pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3))],
    );
    expect(find.textContaining(l10n.enum_equipmentStatus_sold), findsOneWidget);
  });

  testWidgets('history lists ended pairings newest first, deletable', (
    tester,
  ) async {
    final repository = FakePairingRepository();
    final l10n = await pump(
      tester,
      gear: [cylinder('A'), cylinder('B'), cylinder('C'), cylinder('D')],
      repository: repository,
      pairings: [
        pairing('p3', 'A', 'B', DateTime.utc(2026, 9, 14)),
        pairing(
          'p2',
          'A',
          'C',
          DateTime.utc(2025, 5, 1),
          DateTime.utc(2026, 9, 14),
        ),
        pairing(
          'p1',
          'D',
          'A',
          DateTime.utc(2024, 1, 1),
          DateTime.utc(2025, 5, 1),
        ),
      ],
    );
    expect(find.text(l10n.twinSet_history), findsOneWidget);
    final c = tester.getTopLeft(find.textContaining('Double 12 C,')).dy;
    final d = tester.getTopLeft(find.textContaining('Double 12 D,')).dy;
    expect(c, lessThan(d));

    // The first delete is the current pairing's; the first history row is next.
    await tester.tap(find.byTooltip(l10n.twinSet_deletePairing).at(1));
    await tester.pumpAndSettle();
    expect(find.text(l10n.twinSet_deletePairingConfirm), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.twinSet_deletePairing),
    );
    await tester.pumpAndSettle();
    expect(repository.deletes, ['p2']);
  });

  testWidgets('the picker leaves out this cylinder and a retired one, and '
      'offers a spare', (tester) async {
    final repository = FakePairingRepository();
    final l10n = await pump(
      tester,
      repository: repository,
      gear: [
        cylinder('A'),
        cylinder('R', status: EquipmentStatus.retired),
        cylinder('S', status: EquipmentStatus.spare),
      ],
    );
    await tester.tap(find.text(l10n.twinSet_link));
    await tester.pumpAndSettle();
    expect(find.text(l10n.twinSet_pickerTitle), findsOneWidget);
    expect(find.text('Double 12 S'), findsOneWidget);
    expect(find.text('Double 12 R'), findsNothing);
    expect(find.text('Double 12 A'), findsNothing);

    await tester.tap(find.text('Double 12 S'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repository.creates.single.a, 'A');
    expect(repository.creates.single.b, 'S');
    expect(repository.creates.single.replace, isFalse);
  });

  testWidgets('a partner already paired asks to replace, naming both', (
    tester,
  ) async {
    final repository = FakePairingRepository(
      clashOnce: [pairing('bc', 'B', 'C', DateTime.utc(2025, 1, 1))],
    );
    final l10n = await pump(
      tester,
      repository: repository,
      gear: [cylinder('A'), cylinder('B'), cylinder('C')],
    );
    await tester.tap(find.text(l10n.twinSet_link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Double 12 B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.twinSet_replaceTitle), findsOneWidget);
    expect(
      find.textContaining(
        l10n.twinSet_replaceClash('Double 12 B', 'Double 12 C'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(l10n.twinSet_leftAlone('Double 12 C')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.twinSet_replaceConfirm));
    await tester.pumpAndSettle();
    expect(repository.creates.map((c) => c.replace), [false, true]);
  });

  testWidgets('different working pressures warn in the diver\'s unit', (
    tester,
  ) async {
    final repository = FakePairingRepository();
    final l10n = await pump(
      tester,
      repository: repository,
      settings: const AppSettings(pressureUnit: PressureUnit.psi),
      gear: [cylinder('A'), cylinder('B', workingPressureBar: 300)],
    );
    await tester.tap(find.text(l10n.twinSet_link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Double 12 B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.twinSet_pressureMismatchTitle), findsOneWidget);
    expect(find.textContaining('psi'), findsOneWidget);
    expect(find.textContaining('bar'), findsNothing);
    await tester.tap(find.text(l10n.forms_cancel));
    await tester.pumpAndSettle();
    expect(repository.creates, isEmpty);
  });

  testWidgets('unlink ends the current pairing on the chosen day', (
    tester,
  ) async {
    final repository = FakePairingRepository();
    final l10n = await pump(
      tester,
      repository: repository,
      gear: [cylinder('A'), cylinder('B')],
      pairings: [pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3))],
    );
    await tester.tap(find.text(l10n.twinSet_unlink));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repository.ends.single.id, 'p');
  });

  testWidgets('the current pairing can be deleted when it was a mistake', (
    tester,
  ) async {
    final repository = FakePairingRepository();
    final l10n = await pump(
      tester,
      repository: repository,
      gear: [cylinder('A'), cylinder('B')],
      pairings: [pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3))],
    );
    await tester.tap(find.byTooltip(l10n.twinSet_deletePairing));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.twinSet_deletePairing),
    );
    await tester.pumpAndSettle();
    expect(repository.deletes, ['p']);
  });

  testWidgets('replace partner does not offer the current partner', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      gear: [cylinder('A'), cylinder('B'), cylinder('C')],
      pairings: [pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3))],
    );
    await tester.tap(find.text(l10n.twinSet_replace));
    await tester.pumpAndSettle();
    expect(find.text(l10n.twinSet_pickerTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Double 12 B'),
      ),
      findsNothing,
    );
    expect(find.text('Double 12 C'), findsOneWidget);
  });

  testWidgets('a wanted cylinder has no twin set card', (tester) async {
    await pump(
      tester,
      gear: [
        cylinder('A', status: EquipmentStatus.wanted),
        cylinder('B'),
      ],
    );
    expect(find.byType(Card), findsNothing);
  });
}
