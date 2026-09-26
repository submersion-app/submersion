import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/scr_settings_panel.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// Writes every report straight back, as the dive edit page does.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double? injectionRate = 8;
  GasMix? supply = const GasMix(o2: 40, he: 0);

  @override
  Widget build(BuildContext context) {
    return Form(
      child: SingleChildScrollView(
        child: ScrSettingsPanel(
          scrType: ScrType.cmf,
          injectionRate: injectionRate,
          supplyGas: supply,
          onChanged:
              ({
                scrType,
                injectionRate,
                additionRatio,
                orificeSize,
                supplyGas,
                assumedVo2,
                loopO2Min,
                loopO2Max,
                loopO2Avg,
                scrubberType,
                scrubberDurationMinutes,
                scrubberRemainingMinutes,
              }) => setState(() {
                this.injectionRate = injectionRate;
                supply = supplyGas;
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: const Scaffold(body: _Host()),
      ),
    );
  }

  _HostState host(WidgetTester tester) =>
      tester.state<_HostState>(find.byType(_Host));

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('garbage after a clear keeps the last typed injection rate', (
    tester,
  ) async {
    Intl.defaultLocale = 'en_US';
    await pump(tester);

    await tester.enterText(field('Injection Rate'), '9.5');
    await tester.pump();
    await tester.enterText(field('Injection Rate'), '');
    await tester.pump();
    await tester.enterText(field('Injection Rate'), '9..5');
    await tester.pump();

    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    expect(host(tester).injectionRate, 9.5);
  });

  testWidgets('unreadable supply O2 keeps the supply gas', (tester) async {
    Intl.defaultLocale = 'en_US';
    await pump(tester);

    await tester.enterText(field('O₂'), '3..2');
    await tester.pump();

    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    expect(host(tester).supply, const GasMix(o2: 40, he: 0));
  });
}
