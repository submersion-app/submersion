import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_number_attribute_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The unit picker on an equipment number (issue #4534).
void main() {
  late String? savedIntlLocale;
  setUp(() => savedIntlLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  EquipmentAttributeDef def(String key) =>
      EquipmentAttributeCatalog.defFor(key)!;
  final gauge = def('gauge_max_pressure_bar');
  final volume = def(EquipmentAttrKeys.volumeL);
  final dryWeight = def(EquipmentAttrKeys.dryWeightKg);
  final diluent = def('diluent_cylinder_l');

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  );

  /// Records what the field reports.
  final emitted = <EquipmentAttribute>[];
  var cleared = 0;

  Widget field(
    EquipmentAttributeDef d, {
    EquipmentAttribute? current,
    UnitFormatter units = metric,
    double? workingPressureBar,
  }) => EquipmentNumberAttributeField(
    def: d,
    current: current,
    units: units,
    workingPressureBar: workingPressureBar,
    onChanged: emitted.add,
    onCleared: () => cleared++,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
  }) async {
    Intl.defaultLocale = locale.languageCode;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    emitted.clear();
    cleared = 0;
  });

  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey('attr-field-$key')),
    matching: find.byType(EditableText),
  );

  String text(WidgetTester tester, String key) =>
      tester.widget<EditableText>(input(key)).controller.text;

  Future<void> pick(WidgetTester tester, String key, String unit) async {
    await tester.tap(find.byKey(ValueKey('attr-unit-$key')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(unit).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the unit in force on a picker, not in the label', (
    tester,
  ) async {
    await pump(tester, field(gauge));

    expect(
      find.byKey(const ValueKey('attr-unit-gauge_max_pressure_bar')),
      findsOneWidget,
    );
    expect(find.text('Gauge range'), findsOneWidget);
    expect(find.text('Gauge range (bar)'), findsNothing);
    expect(find.text('bar'), findsOneWidget);
  });

  testWidgets('typing in a picked unit stores metric and the unit', (
    tester,
  ) async {
    await pump(tester, field(gauge));
    await pick(tester, gauge.key, 'psi');
    await tester.enterText(input(gauge.key), '4000');

    expect(emitted.last.valueNum, closeTo(275.79, 0.01));
    expect(emitted.last.valueUnit, 'psi');
  });

  testWidgets('picking a unit relabels the figure typed', (tester) async {
    await pump(tester, field(gauge));
    await tester.enterText(input(gauge.key), '300');
    await pick(tester, gauge.key, 'psi');

    expect(text(tester, gauge.key), '300');
    expect(emitted.last.valueNum, closeTo(20.68, 0.01));
    expect(emitted.last.valueUnit, 'psi');
  });

  testWidgets('picking the diver\'s own unit still pins it', (tester) async {
    await pump(tester, field(gauge));
    await tester.enterText(input(gauge.key), '300');
    await pick(tester, gauge.key, 'psi');
    await pick(tester, gauge.key, 'bar');

    expect(emitted.last.valueNum, 300);
    expect(emitted.last.valueUnit, 'bar');
  });

  testWidgets('a stored unit seeds the field in that unit', (tester) async {
    await pump(
      tester,
      field(
        gauge,
        current: EquipmentAttribute.curated(
          equipmentId: 'g1',
          key: gauge.key,
          valueNum: 275.79,
          valueUnit: 'psi',
        ),
      ),
    );

    expect(text(tester, gauge.key), '4000');
    expect(find.text('psi'), findsOneWidget);
  });

  testWidgets('clearing the number keeps a picked unit', (tester) async {
    await pump(tester, field(gauge));
    await pick(tester, gauge.key, 'psi');
    await tester.enterText(input(gauge.key), '4000');
    await tester.enterText(input(gauge.key), '');

    expect(emitted.last.valueNum, isNull);
    expect(emitted.last.valueUnit, 'psi');
    expect(cleared, 0);
  });

  testWidgets('clearing the number with no unit picked clears the field', (
    tester,
  ) async {
    await pump(tester, field(gauge));
    await tester.enterText(input(gauge.key), '300');
    await tester.enterText(input(gauge.key), '');

    expect(cleared, 1);
  });

  testWidgets('Both types in the diver\'s pressure unit', (tester) async {
    await pump(tester, field(gauge));
    await pick(tester, gauge.key, 'Both');
    await tester.enterText(input(gauge.key), '300');

    expect(emitted.last.valueNum, 300);
    expect(emitted.last.valueUnit, 'dual');
  });

  testWidgets('cylinder cubic feet are rated gas capacity', (tester) async {
    await pump(tester, field(volume, workingPressureBar: 206.843));
    await pick(tester, volume.key, 'cuft');
    await tester.enterText(input(volume.key), '77.4');

    expect(emitted.last.valueNum, TankPresets.al80.volumeLiters);
    expect(emitted.last.valueUnit, 'cubicFeet');
  });

  testWidgets(
    'typing a working pressure keeps the cubic feet typed and follows it',
    (tester) async {
      await pump(tester, field(volume, units: imperial));
      await tester.enterText(input(volume.key), '77.4');
      for (final bar in [0.2, 2.07, 20.68, 206.843]) {
        await pump(
          tester,
          field(volume, units: imperial, workingPressureBar: bar),
        );
      }

      expect(text(tester, volume.key), '77.4');
      expect(emitted.last.valueNum, TankPresets.al80.volumeLiters);
    },
  );

  testWidgets('a relabel reads the figure in the diver\'s locale', (
    tester,
  ) async {
    await pump(tester, field(dryWeight), locale: const Locale('de'));
    await tester.enterText(input(dryWeight.key), '7,5');
    await pick(tester, dryWeight.key, 'lbs');

    expect(text(tester, dryWeight.key), '7,5');
    expect(emitted.last.valueNum, closeTo(3.402, 0.001));
  });

  testWidgets('a rebreather cylinder has no picker and reads litres', (
    tester,
  ) async {
    await pump(
      tester,
      field(
        diluent,
        units: imperial,
        current: EquipmentAttribute.curated(
          equipmentId: 'r1',
          key: diluent.key,
          valueNum: 3,
        ),
      ),
    );

    expect(find.byKey(ValueKey('attr-unit-${diluent.key}')), findsNothing);
    expect(text(tester, diluent.key), '3');
    expect(find.textContaining('(L)'), findsOneWidget);
  });

  testWidgets('a unit picked over unreadable text is still reported', (
    tester,
  ) async {
    await pump(
      tester,
      field(
        gauge,
        current: EquipmentAttribute.curated(
          equipmentId: 'g1',
          key: gauge.key,
          valueNum: 300,
        ),
      ),
    );
    await tester.enterText(input(gauge.key), '3..0');
    emitted.clear();
    await pick(tester, gauge.key, 'psi');

    expect(emitted, isNotEmpty);
    expect(emitted.last.valueUnit, 'psi');
  });

  testWidgets(
    'a field following the diver re-reads its figure when the diver\'s units '
    'change',
    (tester) async {
      final current = EquipmentAttribute.curated(
        equipmentId: 'g1',
        key: gauge.key,
        valueNum: 300,
      );
      await pump(tester, field(gauge, current: current));
      expect(text(tester, gauge.key), '300');

      await pump(tester, field(gauge, current: current, units: imperial));

      expect(text(tester, gauge.key), '4351.1');
      expect(find.text('psi'), findsOneWidget);
    },
  );

  testWidgets(
    'a pinned field keeps its figure when the diver\'s units change',
    (tester) async {
      final current = EquipmentAttribute.curated(
        equipmentId: 'g1',
        key: gauge.key,
        valueNum: 275.79,
        valueUnit: 'psi',
      );
      await pump(tester, field(gauge, current: current));
      await pump(tester, field(gauge, current: current, units: imperial));

      expect(text(tester, gauge.key), '4000');
    },
  );

  testWidgets('with Both picked the label says which unit to type in', (
    tester,
  ) async {
    await pump(tester, field(gauge));
    await pick(tester, gauge.key, 'Both');

    expect(find.text('Gauge range (bar)'), findsOneWidget);
  });

  testWidgets('the unit picker is named for its field', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, field(gauge));

    expect(find.bySemanticsLabel(RegExp('Gauge range, Unit')), findsOneWidget);
    semantics.dispose();
  });
}
