import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_mix_pill.dart';

const _mixes = {
  'Air': GasMix(),
  'EAN32': GasMix(o2: 32),
  'O2': GasMix(o2: 100),
  'Tx 18/45': GasMix(o2: 18, he: 45),
};

Future<void> _pump(WidgetTester tester, GasMix mix, Brightness b) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: b),
      home: Scaffold(
        body: Center(child: GasMixPill(gasMix: mix)),
      ),
    ),
  );
}

void main() {
  for (final b in Brightness.values) {
    for (final MapEntry(key: name, value: mix) in _mixes.entries) {
      testWidgets('$name in ${b.name}: chart colour fill, readable label', (
        tester,
      ) async {
        await _pump(tester, mix, b);

        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(GasMixPill),
            matching: find.byType(DecoratedBox),
          ),
        );
        final fill = (box.decoration as BoxDecoration).color!;
        // The same colour the profile chart gives the gas, opaque, in every
        // theme.
        expect(fill, GasColors.forGasMix(mix));
        expect(fill.a, 1.0);

        final label = tester.widget<Text>(find.text(name));
        expect(contrastRatio(label.style!.color!, fill), greaterThan(4.5));
      });
    }
  }
}
