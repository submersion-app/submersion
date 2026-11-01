import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/nav_track/presentation/widgets/nav_track_scale_control.dart';

import '../../../../helpers/test_app.dart';

const _field = ValueKey('nav-track-align-scale-field');
const _up = ValueKey('nav-track-align-scale-up');
const _down = ValueKey('nav-track-align-scale-down');

/// Holds the value the way the alignment page does, so a report feeds back
/// into the control.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.onChanged});

  final double initial;
  final ValueChanged<double> onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double _value = widget.initial;

  void set(double value) => setState(() => _value = value);

  @override
  Widget build(BuildContext context) => NavTrackScaleControl(
    scaleFactor: _value,
    onChanged: (value) {
      widget.onChanged(value);
      set(value);
    },
  );
}

void main() {
  late List<double> reports;

  setUp(() => reports = []);

  Future<void> pump(WidgetTester tester, {double initial = 1}) =>
      tester.pumpWidget(
        testApp(
          child: _Host(initial: initial, onChanged: reports.add),
        ),
      );

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(_field)).controller!.text;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(_field), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('shows 100.0 at the default', (tester) async {
    await pump(tester);
    expect(fieldText(tester), '100.0');
  });

  testWidgets('plus moves up 1%', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(_up));
    await tester.pump();
    expect(reports.single, closeTo(1.01, 1e-9));
    expect(fieldText(tester), '101.0');
  });

  testWidgets('minus moves down 1%', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(_down));
    await tester.pump();
    expect(reports.single, closeTo(0.99, 1e-9));
    expect(fieldText(tester), '99.0');
  });

  testWidgets('steps from a value carrying floating point noise stay clean', (
    tester,
  ) async {
    await pump(tester, initial: 1.1000000000000001);
    await tester.tap(find.byKey(_up));
    await tester.pump();
    expect(reports.single, closeTo(1.11, 1e-12));
    expect(fieldText(tester), '111.0');
  });

  testWidgets('a typed 103.5 reports 1.035', (tester) async {
    await pump(tester);
    await type(tester, '103.5');
    expect(reports.single, closeTo(1.035, 1e-9));
  });

  testWidgets('reads 112,5 under a German locale', (tester) async {
    final previous = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previous);
    Intl.defaultLocale = 'de';
    await pump(tester);
    await type(tester, '112,5');
    expect(reports.single, closeTo(1.125, 1e-9));
  });

  testWidgets('a typed value clamps at 400%', (tester) async {
    await pump(tester);
    await type(tester, '900');
    expect(reports.single, 4);
    expect(fieldText(tester), '400.0');
  });

  testWidgets('a typed value clamps at 25%', (tester) async {
    await pump(tester);
    await type(tester, '10');
    expect(reports.single, 0.25);
    expect(fieldText(tester), '25.0');
  });

  testWidgets('plus stops at 400%', (tester) async {
    await pump(tester, initial: 4);
    await tester.tap(find.byKey(_up));
    await tester.pump();
    expect(reports.last, 4);
  });

  testWidgets('unreadable text restores the field', (tester) async {
    await pump(tester, initial: 1.5);
    await type(tester, 'not a number');
    expect(reports, isEmpty);
    expect(fieldText(tester), '150.0');
  });

  testWidgets('the field has room for 400.0 and its suffix', (tester) async {
    await pump(tester, initial: 4);
    expect(tester.getSize(find.byKey(_field)).width, greaterThanOrEqualTo(104));
  });

  testWidgets('a new value reseeds an unfocused field', (tester) async {
    await pump(tester);
    tester.state<_HostState>(find.byType(_Host)).set(1.38);
    await tester.pump();
    expect(fieldText(tester), '138.0');
  });
}
