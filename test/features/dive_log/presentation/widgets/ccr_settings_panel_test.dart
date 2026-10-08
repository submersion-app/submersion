import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// Records what the panel reports and writes it straight back, the way the
/// dive edit page does, so the parent round-trip after a cleared field is
/// exercised.
class _Host extends StatefulWidget {
  const _Host({required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double? setpointLow = 0.7;
  GasMix? diluent = const GasMix(o2: 21, he: 35);
  int? scrubberMinutes = 180;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        child: CcrSettingsPanel(
          setpointLow: setpointLow,
          diluentGas: diluent,
          scrubberDurationMinutes: scrubberMinutes,
          onChanged:
              ({
                setpointLow,
                setpointHigh,
                setpointDeco,
                diluentGas,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
                loopVolume,
              }) => setState(() {
                this.setpointLow = setpointLow;
                diluent = diluentGas;
                scrubberMinutes = scrubberDurationMinutes;
              }),
        ),
      ),
    );
  }
}

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<GlobalKey<FormState>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: _Host(formKey: formKey)),
      ),
    );
    return formKey;
  }

  _HostState host(WidgetTester tester) =>
      tester.state<_HostState>(find.byType(_Host));

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets(
    'garbage after a clear keeps the last typed setpoint and shows the error',
    (tester) async {
      Intl.defaultLocale = 'en_US';
      final formKey = await pump(tester);

      await tester.enterText(field('Low (Desc/Asc)'), '0.6');
      await tester.pump();
      expect(host(tester).setpointLow, 0.6);

      await tester.enterText(field('Low (Desc/Asc)'), '');
      await tester.pump();
      await tester.enterText(field('Low (Desc/Asc)'), '0..7');
      await tester.pump();

      expect(
        find.text('Enter a valid number (decimal separator: ".")'),
        findsOneWidget,
      );
      expect(
        host(tester).setpointLow,
        0.6,
        reason:
            'must restore the last readable value the diver typed, not the '
            'null the parent round-tripped when the field was cleared',
      );
      expect(formKey.currentState!.validate(), isFalse);
    },
  );

  testWidgets('unreadable diluent O2 keeps the diluent gas', (tester) async {
    Intl.defaultLocale = 'en_US';
    await pump(tester);

    await tester.enterText(field('O₂'), '1..8');
    await tester.pump();

    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    expect(
      host(tester).diluent,
      const GasMix(o2: 21, he: 35),
      reason: 'an unreadable O2 used to drop the diluent gas entirely',
    );
  });

  testWidgets('a fractional scrubber duration asks for a whole number', (
    tester,
  ) async {
    Intl.defaultLocale = 'en_US';
    await pump(tester);

    await tester.enterText(field('Rated'), '12.5');
    await tester.pump();

    expect(find.text('Enter a whole number'), findsOneWidget);
    expect(host(tester).scrubberMinutes, 180);
  });
}
