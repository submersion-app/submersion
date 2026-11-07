import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/twin_fill_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

EquipmentItem cylinder(
  String id,
  String name, {
  double workingPressureBar = 232,
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(
  id: id,
  name: name,
  type: EquipmentType.tank,
  status: status,
  attributes: [
    EquipmentAttribute(
      id: '$id-wp',
      equipmentId: id,
      key: EquipmentAttrKeys.workingPressureBar,
      valueNum: workingPressureBar,
    ),
  ],
);

CylinderPairing pairing(String id, String b, DateTime on, [DateTime? off]) =>
    CylinderPairing(
      id: id,
      cylinderAId: 'eq-1',
      cylinderBId: b,
      pairedOn: on,
      unpairedOn: off,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

class _Fills extends CylinderFillRepository {
  final created = <CylinderFill>[];
  CylinderFill? tied;

  @override
  Future<CylinderFill> create(CylinderFill fill) async {
    created.add(fill);
    return fill.copyWith(id: 'single');
  }

  @override
  Future<List<String>> recentStationNames({int limit = 10}) async => const [];

  @override
  Future<List<String>> recentAnalyzers({int limit = 10}) async => const [];

  @override
  Future<CylinderFill?> tiedFillOf(CylinderFill fill) async => tied;
}

class _Twin extends TwinFillService {
  final twins = <({CylinderFill fill, String partner})>[];
  final edits = <({CylinderFill fill, bool toTied})>[];

  @override
  Future<({CylinderFill fill, CylinderFill partnerFill})> recordTwinFill(
    CylinderFill fill, {
    required String partnerEquipmentId,
  }) async {
    twins.add((fill: fill, partner: partnerEquipmentId));
    return (
      fill: fill.copyWith(id: 'mine'),
      partnerFill: fill.copyWith(id: 'theirs', equipmentId: partnerEquipmentId),
    );
  }

  @override
  Future<void> applyEdit(CylinderFill edited, {required bool toTied}) async =>
      edits.add((fill: edited, toTied: toTied));
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  final today = calendarDay(DateTime.now());

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required _Fills fills,
    required _Twin twin,
    List<CylinderPairing> pairings = const [],
    List<EquipmentItem> gear = const [],
    LogFillSheet sheet = const LogFillSheet(
      passportId: 'pp-1',
      equipmentId: 'eq-1',
    ),
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
      testApp(
        overrides: [
          ...overrides,
          cylinderFillRepositoryProvider.overrideWithValue(fills),
          twinFillServiceProvider.overrideWithValue(twin),
          allPairingsProvider.overrideWith((ref) async => pairings),
          for (final item in gear)
            equipmentItemProvider(item.id).overrideWith((ref) async => item),
        ],
        child: sheet,
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
  }

  final gear = [
    cylinder('eq-1', 'Double 12 A'),
    cylinder('eq-2', 'Double 12 B'),
    cylinder('eq-3', 'Double 12 C'),
  ];

  SwitchListTile twinSwitch(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byKey(const Key('log-fill-twin')));

  Future<void> save(WidgetTester tester, AppLocalizations l10n) async {
    await tester.ensureVisible(find.text(l10n.forms_save));
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
  }

  testWidgets('a paired cylinder shows the twin switch, on', (tester) async {
    final l10n = await pump(
      tester,
      fills: _Fills(),
      twin: _Twin(),
      gear: gear,
      pairings: [pairing('p', 'eq-2', DateTime.utc(2026, 1, 1))],
    );
    expect(
      find.text(l10n.passport_logFill_twinSwitch('Double 12 B')),
      findsOneWidget,
    );
    expect(twinSwitch(tester).value, isTrue);
  });

  testWidgets('an unpaired cylinder has no twin switch', (tester) async {
    await pump(tester, fills: _Fills(), twin: _Twin(), gear: gear);
    expect(find.byKey(const Key('log-fill-twin')), findsNothing);
  });

  testWidgets('a fill dated before a swap names the partner of that day', (
    tester,
  ) async {
    // The swap is tomorrow: today's fill is still the old partner's, though
    // the newest pairing (and the open one) is the new partner's.
    final swap = today.add(const Duration(days: 1));
    final l10n = await pump(
      tester,
      fills: _Fills(),
      twin: _Twin(),
      gear: gear,
      pairings: [
        pairing('new', 'eq-2', swap),
        pairing('old', 'eq-3', DateTime.utc(2025, 1, 1), swap),
      ],
    );
    expect(
      find.text(l10n.passport_logFill_twinSwitch('Double 12 C')),
      findsOneWidget,
    );
  });

  testWidgets('a sold partner starts off and says so', (tester) async {
    final l10n = await pump(
      tester,
      fills: _Fills(),
      twin: _Twin(),
      gear: [
        cylinder('eq-1', 'Double 12 A'),
        cylinder('eq-2', 'Double 12 B', status: EquipmentStatus.sold),
      ],
      pairings: [pairing('p', 'eq-2', DateTime.utc(2026, 1, 1))],
    );
    expect(twinSwitch(tester).value, isFalse);
    expect(
      find.text(
        l10n.passport_logFill_twinSwitch(
          l10n.twinSet_partnerStatus(
            'Double 12 B',
            l10n.enum_equipmentStatus_sold,
          ),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('saving with the switch on records a twin fill', (tester) async {
    final fills = _Fills();
    final twin = _Twin();
    final l10n = await pump(
      tester,
      fills: fills,
      twin: twin,
      gear: gear,
      pairings: [pairing('p', 'eq-2', DateTime.utc(2026, 1, 1))],
    );
    await save(tester, l10n);
    expect(twin.twins.single.partner, 'eq-2');
    expect(fills.created, isEmpty);
  });

  testWidgets('saving with the switch off records one fill', (tester) async {
    final fills = _Fills();
    final twin = _Twin();
    final l10n = await pump(
      tester,
      fills: fills,
      twin: twin,
      gear: gear,
      pairings: [pairing('p', 'eq-2', DateTime.utc(2026, 1, 1))],
    );
    await tester.tap(find.byKey(const Key('log-fill-twin')));
    await tester.pumpAndSettle();
    await save(tester, l10n);
    expect(fills.created, hasLength(1));
    expect(twin.twins, isEmpty);
  });

  testWidgets('a pressure above the partner\'s rating warns, in psi', (
    tester,
  ) async {
    final twin = _Twin();
    final l10n = await pump(
      tester,
      fills: _Fills(),
      twin: twin,
      settings: const AppSettings(pressureUnit: PressureUnit.psi),
      gear: [
        cylinder('eq-1', 'Double 12 A', workingPressureBar: 300),
        cylinder('eq-2', 'Double 12 B', workingPressureBar: 232),
      ],
      pairings: [pairing('p', 'eq-2', DateTime.utc(2026, 1, 1))],
    );
    await tester.enterText(find.byKey(const Key('logFill_pressure')), '4000');
    await save(tester, l10n);
    expect(find.text(l10n.passport_logFill_overPressureTitle), findsOneWidget);
    expect(find.textContaining('Double 12 B'), findsWidgets);
    expect(find.textContaining('psi'), findsWidgets);
    await tester.tap(find.text(l10n.passport_logFill_back));
    await tester.pumpAndSettle();
    expect(twin.twins, isEmpty);

    await save(tester, l10n);
    await tester.tap(find.text(l10n.passport_logFill_saveAnyway));
    await tester.pumpAndSettle();
    expect(twin.twins, hasLength(1));
  });

  testWidgets('both cylinders above their rating are each named', (
    tester,
  ) async {
    final twin = _Twin();
    final l10n = await pump(
      tester,
      fills: _Fills(),
      twin: twin,
      gear: [
        cylinder('eq-1', 'Double 12 A', workingPressureBar: 200),
        cylinder('eq-2', 'Double 12 B', workingPressureBar: 210),
      ],
      pairings: [pairing('p', 'eq-2', DateTime.utc(2026, 1, 1))],
    );
    await tester.enterText(find.byKey(const Key('logFill_pressure')), '230');
    await save(tester, l10n);
    expect(find.textContaining('Double 12 A'), findsWidgets);
    await tester.tap(find.text(l10n.passport_logFill_saveAnyway));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_overPressureTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Double 12 B'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.passport_logFill_saveAnyway));
    await tester.pumpAndSettle();
    expect(twin.twins, hasLength(1));
  });

  group('edit mode', () {
    final existing = CylinderFill(
      id: 'f1',
      passportId: 'pp-1',
      equipmentId: 'eq-1',
      filledAt: DateTime(2026, 10, 2, 9, 15),
      o2Percent: 32,
      pressureBar: 220,
      stationName: 'Blue Water Fills',
      notes: 'note',
      filledTogetherId: 'g',
      createdAt: DateTime(2026, 10, 2),
      updatedAt: DateTime(2026, 10, 2),
    );

    testWidgets('prefills the fill, says Edit fill, and has no switch', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        fills: _Fills(),
        twin: _Twin(),
        gear: gear,
        pairings: [pairing('p', 'eq-2', DateTime.utc(2026, 1, 1))],
        sheet: LogFillSheet(
          passportId: 'pp-1',
          equipmentId: 'eq-1',
          editing: existing,
        ),
      );
      expect(find.text(l10n.passport_logFill_editTitle), findsOneWidget);
      expect(find.byKey(const Key('log-fill-twin')), findsNothing);
      String field(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(field('logFill_o2'), '32');
      expect(field('logFill_pressure'), '220');
      expect(find.text('Blue Water Fills'), findsOneWidget);
    });

    for (final (answer, toTied) in [('both', true), ('one', false)]) {
      testWidgets('a tied fill asks, and $answer reaches applyEdit', (
        tester,
      ) async {
        final fills = _Fills()
          ..tied = existing.copyWith(id: 'f2', equipmentId: 'eq-2');
        final twin = _Twin();
        final l10n = await pump(
          tester,
          fills: fills,
          twin: twin,
          gear: gear,
          sheet: LogFillSheet(
            passportId: 'pp-1',
            equipmentId: 'eq-1',
            editing: existing,
          ),
        );
        await tester.enterText(
          find.byKey(const Key('logFill_pressure')),
          '230',
        );
        await save(tester, l10n);
        expect(
          find.text(l10n.passport_logFill_applyToTied('Double 12 B')),
          findsOneWidget,
        );
        await tester.tap(
          find.text(
            toTied
                ? l10n.passport_logFill_applyBoth
                : l10n.passport_logFill_onlyThisOne,
          ),
        );
        await tester.pumpAndSettle();
        expect(twin.edits.single.toTied, toTied);
        expect(twin.edits.single.fill.id, 'f1');
        expect(twin.edits.single.fill.pressureBar, 230);
      });
    }

    // The partner is rated 232 bar, the cylinder edited 300 bar, so only the
    // partner can be above its rating.
    final ratedGear = [
      cylinder('eq-1', 'Double 12 A', workingPressureBar: 300),
      cylinder('eq-2', 'Double 12 B'),
    ];

    testWidgets('a raised pressure applied to both warns above the '
        'partner\'s rating', (tester) async {
      final fills = _Fills()
        ..tied = existing.copyWith(id: 'f2', equipmentId: 'eq-2');
      final twin = _Twin();
      final l10n = await pump(
        tester,
        fills: fills,
        twin: twin,
        gear: ratedGear,
        sheet: LogFillSheet(
          passportId: 'pp-1',
          equipmentId: 'eq-1',
          editing: existing,
        ),
      );
      await tester.enterText(find.byKey(const Key('logFill_pressure')), '260');
      await save(tester, l10n);
      await tester.tap(find.text(l10n.passport_logFill_applyBoth));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.passport_logFill_overPressureTitle),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Double 12 B'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.passport_logFill_back));
      await tester.pumpAndSettle();
      expect(twin.edits, isEmpty);

      await save(tester, l10n);
      await tester.tap(find.text(l10n.passport_logFill_applyBoth));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.passport_logFill_saveAnyway));
      await tester.pumpAndSettle();
      expect(twin.edits.single.toTied, isTrue);
      expect(twin.edits.single.fill.pressureBar, 260);
    });

    for (final (label, onlyThisOne, pressure) in [
      ('only this one', true, '260'),
      ('an untouched pressure', false, null),
    ]) {
      testWidgets('$label does not warn', (tester) async {
        final above = existing.copyWith(pressureBar: 250);
        final fills = _Fills()
          ..tied = above.copyWith(id: 'f2', equipmentId: 'eq-2');
        final twin = _Twin();
        final l10n = await pump(
          tester,
          fills: fills,
          twin: twin,
          gear: ratedGear,
          sheet: LogFillSheet(
            passportId: 'pp-1',
            equipmentId: 'eq-1',
            editing: above,
          ),
        );
        if (pressure != null) {
          await tester.enterText(
            find.byKey(const Key('logFill_pressure')),
            pressure,
          );
        }
        await save(tester, l10n);
        await tester.tap(
          find.text(
            onlyThisOne
                ? l10n.passport_logFill_onlyThisOne
                : l10n.passport_logFill_applyBoth,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.passport_logFill_overPressureTitle),
          findsNothing,
        );
        expect(twin.edits, hasLength(1));
      });
    }

    testWidgets('an edit in psi keeps an untouched pressure exactly', (
      tester,
    ) async {
      final twin = _Twin();
      final l10n = await pump(
        tester,
        fills: _Fills(),
        twin: twin,
        gear: gear,
        settings: const AppSettings(
          pressureUnit: PressureUnit.psi,
          temperatureUnit: TemperatureUnit.fahrenheit,
        ),
        sheet: LogFillSheet(
          passportId: 'pp-1',
          equipmentId: 'eq-1',
          editing: existing.copyWith(temperatureC: 21.53),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, l10n.passport_logFill_notes),
        'edited note',
      );
      await save(tester, l10n);
      final saved = twin.edits.single.fill;
      expect(saved.notes, 'edited note');
      expect(saved.pressureBar, 220);
      expect(saved.temperatureC, 21.53);
    });

    testWidgets('a fill with no tied row saves without asking', (tester) async {
      final twin = _Twin();
      final l10n = await pump(
        tester,
        fills: _Fills(),
        twin: twin,
        gear: gear,
        sheet: LogFillSheet(
          passportId: 'pp-1',
          equipmentId: 'eq-1',
          editing: existing,
        ),
      );
      await save(tester, l10n);
      expect(twin.edits.single.toTied, isFalse);
    });
  });
}
