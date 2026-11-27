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
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_link_flow.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_twin_set_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

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

/// Records what Save asked of the repository.
class FakePairingRepository extends CylinderPairingRepository {
  final creates = <({String a, String b, DateTime on, bool replace})>[];
  final ends = <({String id, DateTime end})>[];
  final deletes = <String>[];

  @override
  Future<CylinderPairing> createPairing({
    required String cylinderAId,
    required String cylinderBId,
    required DateTime pairedOn,
    DateTime? unpairedOn,
    bool replace = false,
  }) async {
    creates.add((
      a: cylinderAId,
      b: cylinderBId,
      on: pairedOn,
      replace: replace,
    ));
    return pairing('new', cylinderAId, cylinderBId, calendarDay(pairedOn));
  }

  @override
  Future<void> endPairing(String id, DateTime unpairedOn) async {
    ends.add((id: id, end: unpairedOn));
  }

  @override
  Future<void> deletePairing(String id) async {
    deletes.add(id);
  }
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

  // Issue #4527, phase 3: the card acts only in the gear item's sitting,
  // and every pairing change there waits for Save.
  late EditSession<EquipmentItem> session;

  setUp(() {
    session = EditSession(cylinder('A'));
    addTearDown(session.dispose);
  });

  Widget held() =>
      TwinSetCard(equipmentId: 'A', working: session.working, editing: session);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required List<EquipmentItem> gear,
    List<CylinderPairing> pairings = const [],
    FakePairingRepository? repository,
    AppSettings? settings,
    Widget card = const TwinSetCard(equipmentId: 'A'),
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
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TwinSetCard)));
  }

  /// The one pairing the sitting holds as made.
  HeldPairingCreate heldCreate() =>
      heldPairingSteps(session).single as HeldPairingCreate;

  group('locked', () {
    testWidgets('an unlinked cylinder offers no link', (tester) async {
      final l10n = await pump(tester, gear: [cylinder('A'), cylinder('B')]);
      expect(find.text(l10n.twinSet_title), findsOneWidget);
      expect(find.text(l10n.twinSet_none), findsOneWidget);
      expect(find.text(l10n.twinSet_link), findsNothing);
    });

    testWidgets('a linked cylinder shows its pairings and offers no action', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B'), cylinder('C')],
        pairings: [
          pairing('p2', 'A', 'B', DateTime.utc(2026, 3, 3)),
          pairing(
            'p1',
            'A',
            'C',
            DateTime.utc(2025, 1, 1),
            DateTime.utc(2026, 3, 3),
          ),
        ],
      );
      expect(find.text('Double 12 B'), findsOneWidget);
      expect(find.text(l10n.twinSet_history), findsOneWidget);
      expect(find.text(l10n.twinSet_replace), findsNothing);
      expect(find.text(l10n.twinSet_unlink), findsNothing);
      expect(find.byTooltip(l10n.twinSet_deletePairing), findsNothing);
    });
  });

  group('in a sitting', () {
    testWidgets('linking holds the pairing until Save', (tester) async {
      final repository = FakePairingRepository();
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B')],
        repository: repository,
        card: held(),
      );

      await tester.tap(find.text(l10n.twinSet_link));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Double 12 B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repository.creates, isEmpty);
      expect(find.text('Double 12 B'), findsOneWidget);
      expect(find.byType(RecordChangedDot), findsOneWidget);
      expect(session.changedCardIds, {GearItemCardId.twinSet.name});

      await session.runHeldWrites();
      expect(repository.creates.single.b, 'B');
    });

    testWidgets('unlink and delete are held, and run in order at Save', (
      tester,
    ) async {
      final repository = FakePairingRepository();
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B'), cylinder('C')],
        repository: repository,
        pairings: [
          pairing('p2', 'A', 'B', DateTime.utc(2025, 5, 1)),
          pairing(
            'p1',
            'A',
            'C',
            DateTime.utc(2024, 1, 1),
            DateTime.utc(2025, 5, 1),
          ),
        ],
        card: held(),
      );

      await tester.tap(find.text(l10n.twinSet_unlink));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.twinSet_none), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.twinSet_deletePairing).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.twinSet_deletePairing),
      );
      await tester.pumpAndSettle();

      expect(repository.ends, isEmpty);
      expect(repository.deletes, isEmpty);
      await session.runHeldWrites();
      expect(repository.ends.single.id, 'p2');
      expect(repository.deletes, ['p1']);
    });

    testWidgets('Worn as set to Twin set in the sitting hides an unpaired '
        'card', (tester) async {
      final doubles = cylinder('A').copyWith(
        attributes: [
          ...cylinder('A').attributes,
          const EquipmentAttribute(
            id: 'A-worn',
            equipmentId: 'A',
            key: EquipmentAttrKeys.wornAs,
            valueText: kWornAsTwinSet,
          ),
        ],
      );
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B')],
        card: TwinSetCard(equipmentId: 'A', working: doubles, editing: session),
      );

      expect(find.text(l10n.twinSet_title), findsNothing);
    });

    testWidgets('an unlinked cylinder offers a link', (tester) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B')],
        card: held(),
      );
      expect(find.text(l10n.twinSet_title), findsOneWidget);
      expect(find.text(l10n.twinSet_none), findsOneWidget);
      expect(find.text(l10n.twinSet_link), findsOneWidget);
      expect(find.text(l10n.twinSet_unlink), findsNothing);
    });

    testWidgets('a linked cylinder shows its partner and since date, with '
        'replace and unlink', (tester) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B')],
        pairings: [pairing('p', 'B', 'A', DateTime.utc(2026, 3, 3))],
        card: held(),
      );
      expect(find.text('Double 12 B'), findsOneWidget);
      expect(find.textContaining(l10n.twinSet_since('')), findsOneWidget);
      expect(find.textContaining('2026'), findsWidgets);
      expect(find.text(l10n.twinSet_replace), findsOneWidget);
      expect(find.text(l10n.twinSet_unlink), findsOneWidget);
      expect(find.text(l10n.twinSet_link), findsNothing);
    });

    testWidgets('history lists ended pairings newest first, and a delete is '
        'held', (tester) async {
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
        card: held(),
      );
      expect(find.text(l10n.twinSet_history), findsOneWidget);
      final c = tester.getTopLeft(find.textContaining('Double 12 C,')).dy;
      final d = tester.getTopLeft(find.textContaining('Double 12 D,')).dy;
      expect(c, lessThan(d));

      // The first delete is the current pairing's; the first history row is
      // next.
      await tester.tap(find.byTooltip(l10n.twinSet_deletePairing).at(1));
      await tester.pumpAndSettle();
      expect(find.text(l10n.twinSet_deletePairingConfirm), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.twinSet_deletePairing),
      );
      await tester.pumpAndSettle();

      expect(heldPairingSteps(session), [
        const HeldPairingDelete(pairingId: 'p2'),
      ]);
      expect(find.textContaining('Double 12 C,'), findsNothing);
      expect(repository.deletes, isEmpty);
    });

    testWidgets('the picker leaves out this cylinder and a retired one, and '
        'offers a spare', (tester) async {
      final l10n = await pump(
        tester,
        gear: [
          cylinder('A'),
          cylinder('R', status: EquipmentStatus.retired),
          cylinder('S', status: EquipmentStatus.spare),
        ],
        card: held(),
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
      expect(heldCreate().cylinderAId, 'A');
      expect(heldCreate().cylinderBId, 'S');
      expect(heldCreate().replace, isFalse);
    });

    testWidgets('a partner already paired asks to replace, naming both', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B'), cylinder('C')],
        pairings: [pairing('bc', 'B', 'C', DateTime.utc(2025, 1, 1))],
        card: held(),
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
      expect(heldCreate().cylinderBId, 'B');
      expect(heldCreate().replace, isTrue);
    });

    testWidgets('different working pressures warn in the diver\'s unit', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        settings: const AppSettings(pressureUnit: PressureUnit.psi),
        gear: [cylinder('A'), cylinder('B', workingPressureBar: 300)],
        card: held(),
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
      expect(heldPairingSteps(session), isEmpty);
    });

    testWidgets('unlink ends the current pairing on the chosen day', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B')],
        pairings: [pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3))],
        card: held(),
      );
      await tester.tap(find.text(l10n.twinSet_unlink));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final ended = heldPairingSteps(session).single as HeldPairingEnd;
      expect(ended.pairingId, 'p');
      expect(ended.unpairedOn, calendarDay(DateTime.now()));
    });

    testWidgets('the current pairing can be deleted when it was a mistake', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B')],
        pairings: [pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3))],
        card: held(),
      );
      await tester.tap(find.byTooltip(l10n.twinSet_deletePairing));
      await tester.pumpAndSettle();
      expect(find.text(l10n.twinSet_deletePairingConfirm), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.twinSet_deletePairing),
      );
      await tester.pumpAndSettle();
      expect(heldPairingSteps(session), [
        const HeldPairingDelete(pairingId: 'p'),
      ]);
      expect(find.text(l10n.twinSet_none), findsOneWidget);
    });

    testWidgets('replace partner does not offer the current partner', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B'), cylinder('C')],
        pairings: [pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3))],
        card: held(),
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

    Future<void> linkTo(
      WidgetTester tester,
      AppLocalizations l10n,
      String name,
    ) async {
      await tester.tap(find.text(l10n.twinSet_link));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('with no other cylinder the picker says so', (tester) async {
      final l10n = await pump(tester, gear: [cylinder('A')], card: held());
      await tester.tap(find.text(l10n.twinSet_link));
      await tester.pumpAndSettle();
      expect(find.text(l10n.twinSet_pickerEmpty), findsOneWidget);
    });

    testWidgets('a clash replacing cannot clear names the pairing and holds '
        'nothing', (tester) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B'), cylinder('C')],
        pairings: [
          pairing(
            'later',
            'B',
            'C',
            DateTime.now().add(const Duration(days: 30)),
          ),
        ],
        card: held(),
      );
      await linkTo(tester, l10n, 'Double 12 B');
      expect(find.text(l10n.twinSet_clashTitle), findsOneWidget);
      expect(
        find.textContaining(
          l10n.twinSet_pairNames('Double 12 B', 'Double 12 C'),
        ),
        findsOneWidget,
      );
      expect(heldPairingSteps(session), isEmpty);
    });

    testWidgets('an unlink that would overlap a later pairing names it', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B'), cylinder('C')],
        pairings: [
          pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3)),
          pairing('x', 'B', 'C', DateTime.utc(2026, 5, 1)),
        ],
        card: held(),
      );
      await tester.tap(find.text(l10n.twinSet_unlink));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.twinSet_clashTitle), findsOneWidget);
      expect(heldPairingSteps(session), isEmpty);
    });

    // The card offers no day before the start, so the sitting meets this
    // only when the pairing stored by now started later than the one shown
    // (another device moved its start).
    testWidgets('an unlink before the start says when the pairing began', (
      tester,
    ) async {
      final shown = pairing('p', 'A', 'B', DateTime.utc(2026, 3, 3));
      final moved = pairing('p', 'A', 'B', DateTime.utc(2099, 1, 1));
      final writer = SittingPairingWrites(
        session,
        () async => [moved],
        FakePairingRepository(),
      );
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B')],
        pairings: [shown],
        card: Column(
          children: [
            const TwinSetCard(equipmentId: 'A'),
            Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    unlinkTwinSet(context, ref, shown, writer: writer),
                child: const Text('Unlink'),
              ),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // The message up to the date it names.
      final prefix = l10n.twinSet_endBeforeStart('#').split('#').first;
      expect(find.textContaining(prefix), findsOneWidget);
      expect(heldPairingSteps(session), isEmpty);
    });
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

  group('doubles kept as one item (issue #4641)', () {
    EquipmentItem d12() {
      final base = cylinder('A');
      return base.copyWith(
        attributes: [
          ...base.attributes,
          const EquipmentAttribute(
            id: 'A-worn',
            equipmentId: 'A',
            key: EquipmentAttrKeys.wornAs,
            valueText: kWornAsTwinSet,
          ),
        ],
      );
    }

    testWidgets('an item worn as a twin set with no pairing has no card', (
      tester,
    ) async {
      await pump(tester, gear: [d12(), cylinder('B')]);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('another cylinder is not offered one as a partner', (
      tester,
    ) async {
      final c = cylinder('C');
      final doubles = c.copyWith(
        attributes: [
          ...c.attributes,
          const EquipmentAttribute(
            id: 'C-worn',
            equipmentId: 'C',
            key: EquipmentAttrKeys.wornAs,
            valueText: kWornAsTwinSet,
          ),
        ],
      );
      final l10n = await pump(
        tester,
        gear: [cylinder('A'), cylinder('B'), doubles],
        card: held(),
      );
      await tester.tap(find.text(l10n.twinSet_link));
      await tester.pumpAndSettle();
      expect(find.text('Double 12 B'), findsOneWidget);
      expect(find.text('Double 12 C'), findsNothing);
    });

    testWidgets('a pairing it already has still shows', (tester) async {
      final l10n = await pump(
        tester,
        gear: [d12(), cylinder('B')],
        pairings: [
          pairing(
            'p',
            'A',
            'B',
            DateTime.utc(2025, 1, 1),
            DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      expect(find.text(l10n.twinSet_title), findsOneWidget);
      expect(find.text(l10n.twinSet_history), findsOneWidget);
    });
  });
}
