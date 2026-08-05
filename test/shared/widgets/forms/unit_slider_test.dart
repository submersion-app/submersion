import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

void main() {
  Widget host(UnitAxis axis, double value, ValueChanged<double> onChanged) {
    return MaterialApp(
      home: Scaffold(
        body: UnitSlider(
          icon: Icons.air,
          label: 'Your SAC',
          value: value,
          axis: axis,
          onChanged: onChanged,
        ),
      ),
    );
  }

  testWidgets('renders imperial SAC with two decimals', (tester) async {
    final axis = UnitAxis.stressedSac(
      const UnitFormatter(AppSettings(volumeUnit: VolumeUnit.cubicFeet)),
    );
    await tester.pumpWidget(host(axis, 28.3, (_) {}));
    // 28.3 L/min = 0.999 cuft/min. Rendering at 0 decimals would show "1".
    expect(find.text('1.00 cuft/min'), findsOneWidget);
  });

  testWidgets('emits canonical values from onChanged', (tester) async {
    double? emitted;
    final axis = UnitAxis.stressedSac(
      const UnitFormatter(AppSettings(volumeUnit: VolumeUnit.cubicFeet)),
    );
    await tester.pumpWidget(host(axis, 28.3, (v) => emitted = v));

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1.40); // display-space cuft/min

    // 1.40 cuft/min back in canonical L/min is ~39.6, not 1.40.
    expect(emitted, isNotNull);
    expect(emitted, greaterThan(30));
  });

  testWidgets('metric SAC renders whole numbers', (tester) async {
    final axis = UnitAxis.stressedSac(const UnitFormatter(AppSettings()));
    await tester.pumpWidget(host(axis, 20, (_) {}));
    expect(find.text('20 L/min'), findsOneWidget);
  });

  testWidgets('clamps an out-of-range canonical value for display', (
    tester,
  ) async {
    final axis = UnitAxis.ascentRate(const UnitFormatter(AppSettings()));
    // 100 m/min is far above the 18 m/min ceiling; the Slider would assert
    // if handed a value outside its own min/max.
    await tester.pumpWidget(host(axis, 100, (_) {}));
    expect(tester.takeException(), isNull);
    expect(find.text('18 m/min'), findsOneWidget);
  });

  testWidgets('exposes the readout to accessibility', (tester) async {
    final axis = UnitAxis.stressedSac(const UnitFormatter(AppSettings()));
    await tester.pumpWidget(host(axis, 20, (_) {}));
    expect(find.bySemanticsLabel('Your SAC: 20 L/min'), findsOneWidget);
  });
}
