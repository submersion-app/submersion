import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';

const _back = DiveTank(id: 'back', volume: 12);
const _deco = DiveTank(
  id: 'deco',
  volume: 7,
  role: TankRole.deco,
  gasMix: GasMix(o2: 50),
  order: 1,
);

GasSwitch _sw(String id, int timestamp, String tankId, {double? depth}) =>
    GasSwitch(
      id: id,
      diveId: 'dive-1',
      timestamp: timestamp,
      tankId: tankId,
      depth: depth,
      createdAt: DateTime(2026),
    );

typedef _Change = ({GasSwitch updated, GasSwitchField field});

class _Harness {
  final formKey = GlobalKey<FormState>();
  final changes = <_Change>[];
  final removed = <String>[];
  final settled = <String>[];
  var added = 0;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required List<GasSwitch> switches,
  int? maxTimestamp = 1800,
  int removedWithTankCount = 0,
  bool imperial = false,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final h = _Harness();
  final units = UnitFormatter(
    AppSettings(depthUnit: imperial ? DepthUnit.feet : DepthUnit.meters),
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Form(
            key: h.formKey,
            child: GasSwitchesEditor(
              switches: switches,
              tanks: const [_back, _deco],
              units: units,
              maxTimestamp: maxTimestamp,
              startingTank: _back,
              removedWithTankCount: removedWithTankCount,
              onChanged: (updated, field) =>
                  h.changes.add((updated: updated, field: field)),
              onRemove: h.removed.add,
              onTimeSettled: h.settled.add,
              onAdd: () => h.added++,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

Finder _timeField(String id) => find.descendant(
  of: find.byKey(ValueKey('gas-switch-time-$id')),
  matching: find.byType(TextFormField),
);

Finder _depthField(String id) => find.byKey(ValueKey('gas-switch-depth-$id'));

void main() {
  testWidgets('a narrow row puts the cylinder picker on its own line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(380, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              child: GasSwitchesEditor(
                switches: [_sw('gs-1', 600, 'deco', depth: 21.0)],
                tanks: const [_back, _deco],
                units: const UnitFormatter(AppSettings()),
                maxTimestamp: 1800,
                startingTank: _back,
                removedWithTankCount: 0,
                onChanged: (_, _) {},
                onRemove: (_) {},
                onAdd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final time = tester.getTopLeft(_timeField('gs-1'));
    final picker = tester.getTopLeft(
      find.byKey(const ValueKey('gas-switch-tank-gs-1')),
    );
    final depth = tester.getTopLeft(_depthField('gs-1'));
    expect(picker.dy, greaterThan(time.dy));
    expect(depth.dy, time.dy);
  });

  testWidgets('rows keep the order given and show the starting cylinder', (
    tester,
  ) async {
    // The page owns the order, so a time being typed does not move its row;
    // the editor never re-sorts on its own.
    await _pump(
      tester,
      switches: [_sw('gs-b', 1200, 'back'), _sw('gs-a', 600, 'deco')],
    );

    final times = tester
        .widgetList<MinutesSecondsField>(find.byType(MinutesSecondsField))
        .map((f) => f.seconds)
        .toList();
    expect(times, [1200, 600]);
    expect(find.text('Starts on Tank 1 · Back Gas · Air'), findsOneWidget);
  });

  testWidgets('leaving a time field reports the settled switch', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      switches: [_sw('gs-1', 600, 'deco'), _sw('gs-2', 900, 'back')],
    );

    await tester.enterText(_timeField('gs-1'), '20:00');
    expect(h.settled, isEmpty);
    await tester.tap(_timeField('gs-2'));
    await tester.pump();

    expect(h.settled, ['gs-1']);
  });

  testWidgets(
    'a time one second past the runtime fails validation, the runtime itself '
    'passes',
    (tester) async {
      final h = await _pump(tester, switches: [_sw('gs-1', 600, 'deco')]);

      await tester.enterText(_timeField('gs-1'), '30:00');
      expect(h.formKey.currentState!.validate(), isTrue);

      await tester.enterText(_timeField('gs-1'), '30:01');
      expect(h.formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Must be within the dive'), findsOneWidget);
    },
  );

  testWidgets('two switches at one time fail validation', (tester) async {
    final h = await _pump(
      tester,
      switches: [_sw('gs-1', 600, 'deco'), _sw('gs-2', 900, 'back')],
    );

    await tester.enterText(_timeField('gs-2'), '10:00');
    expect(h.formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('Another switch is at this time'), findsOneWidget);
  });

  testWidgets('a typed depth in feet reaches onChanged in metres', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      switches: [_sw('gs-1', 600, 'deco')],
      imperial: true,
    );

    await tester.enterText(_depthField('gs-1'), '66');

    expect(h.changes, hasLength(1));
    expect(h.changes.single.field, GasSwitchField.depth);
    expect(h.changes.single.updated.depth, closeTo(20.1, 0.1));
  });

  testWidgets('clearing the depth reports null', (tester) async {
    final h = await _pump(
      tester,
      switches: [_sw('gs-1', 600, 'deco', depth: 21.0)],
    );

    expect(find.text('21.0'), findsOneWidget);
    await tester.enterText(_depthField('gs-1'), '');

    expect(h.changes.single.updated.depth, isNull);
    expect(h.changes.single.field, GasSwitchField.depth);
  });

  testWidgets('a typed time reaches onChanged with the time field', (
    tester,
  ) async {
    final h = await _pump(tester, switches: [_sw('gs-1', 600, 'deco')]);

    await tester.enterText(_timeField('gs-1'), '15:00');

    expect(h.changes.single.updated.timestamp, 900);
    expect(h.changes.single.field, GasSwitchField.time);
  });

  testWidgets('remove and add call back', (tester) async {
    final h = await _pump(tester, switches: [_sw('gs-1', 600, 'deco')]);

    await tester.tap(find.byKey(const ValueKey('gas-switch-remove-gs-1')));
    await tester.tap(find.text('Add Switch'));

    expect(h.removed, ['gs-1']);
    expect(h.added, 1);
  });

  testWidgets('the removed-with-tank notice shows for a positive count', (
    tester,
  ) async {
    await _pump(tester, switches: const [], removedWithTankCount: 1);

    expect(find.text('1 gas switch removed with its tank'), findsOneWidget);
  });
}
