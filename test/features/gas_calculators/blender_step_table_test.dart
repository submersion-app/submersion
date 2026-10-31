import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_step_table.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _steps = [
  BlendStep(
    fillGas: null,
    fillGasIndex: null,
    pressureBar: 50,
    addedBar: 0,
    resultingMix: GasMix(o2: 21),
    addedVolumePerLiter: 0,
  ),
  BlendStep(
    fillGas: GasMix(o2: 0, he: 100),
    fillGasIndex: 0,
    pressureBar: 145,
    addedBar: 95,
    resultingMix: GasMix(o2: 12.1, he: 34.5),
    addedVolumePerLiter: 95,
  ),
  BlendStep(
    fillGas: GasMix(o2: 21),
    fillGasIndex: 1,
    pressureBar: 200,
    addedBar: 55,
    resultingMix: GasMix(o2: 18, he: 45),
    addedVolumePerLiter: 55,
  ),
];

/// Pumps the table at [width]. The test font sets every glyph one font size
/// wide, plus the theme's letter spacing, which the text scale leaves alone.
/// So a value of n characters measures n(14 + 0.25) at the default scale,
/// rounded up: "+ Helium" 114, "+95.0" and "145.0" 72, "12.1/34.5" 129. A
/// header word of n characters measures n(11 + 0.5): "Pressure" 92.
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  AppSettings settings = const AppSettings(),
  int decimals = 1,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(Size(width + 100, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: BlenderStepTable(
                  steps: _steps,
                  units: UnitFormatter(settings),
                  decimals: decimals,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _cellWidth(WidgetTester tester, String text) =>
    tester.getSize(find.text(text)).width;

void main() {
  group('blenderColumnWidths', () {
    test('shares the width evenly when every minimum fits', () {
      expect(blenderColumnWidths([10, 20, 30, 40], 400), [100, 100, 100, 100]);
    });

    test('a column needing more keeps its minimum, the rest share the '
        'remainder', () {
      expect(blenderColumnWidths([10, 20, 30, 160], 400), [80, 80, 80, 160]);
      expect(blenderColumnWidths([160, 30, 20, 10], 400), [160, 80, 80, 80]);
    });

    test('the smaller remainder can push a second column to its minimum', () {
      // An even share is 85, which suits the 80, but once the 130 is taken
      // the other three only get 70 each.
      expect(blenderColumnWidths([80, 10, 10, 130], 340), [80, 65, 65, 130]);
    });

    test('never goes below a minimum, even when they cannot all fit', () {
      expect(blenderColumnWidths([100, 40, 40, 100], 200), [100, 40, 40, 100]);
    });
  });

  group('BlenderStepTable', () {
    testWidgets('headers put the unit on its own second line', (tester) async {
      await _pump(tester, width: 800);

      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Top up\n(bar)'), findsOneWidget);
      expect(find.text('Pressure\n(bar)'), findsOneWidget);
      expect(find.text('Mix\nO₂/He'), findsOneWidget);
    });

    testWidgets('headers follow the diver\'s pressure unit', (tester) async {
      await _pump(
        tester,
        width: 800,
        settings: const AppSettings(pressureUnit: PressureUnit.psi),
        decimals: 0,
      );

      expect(find.text('Top up\n(psi)'), findsOneWidget);
      expect(find.text('Pressure\n(psi)'), findsOneWidget);
    });

    testWidgets('the mix column drops the Tx prefix and the spaced slash', (
      tester,
    ) async {
      await _pump(tester, width: 800);

      expect(find.text('Air'), findsOneWidget);
      expect(find.text('12.1/34.5'), findsOneWidget);
      expect(find.text('18/45'), findsOneWidget);
      expect(find.textContaining('Tx'), findsNothing);
    });

    testWidgets('the action column still names a trimix fill gas in full', (
      tester,
    ) async {
      const trimixTopUp = BlendStep(
        fillGas: GasMix(o2: 21, he: 35),
        fillGasIndex: 2,
        pressureBar: 200,
        addedBar: 55,
        resultingMix: GasMix(o2: 18, he: 45),
        addedVolumePerLiter: 55,
      );
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlenderStepTable(
              steps: [trimixTopUp],
              units: UnitFormatter(AppSettings()),
              decimals: 1,
            ),
          ),
        ),
      );

      expect(find.text('+ Tx 21/35'), findsOneWidget);
      expect(find.text('18/45'), findsOneWidget);
    });

    testWidgets('all four columns are equal when there is room', (
      tester,
    ) async {
      await _pump(tester, width: 800);

      expect(_cellWidth(tester, '+ Helium'), 200);
      expect(_cellWidth(tester, '+95.0'), 200);
      expect(_cellWidth(tester, '145.0'), 200);
      expect(_cellWidth(tester, '12.1/34.5'), 200);
    });

    testWidgets('a long mix widens its column and the others give it up', (
      tester,
    ) async {
      await _pump(tester, width: 480);

      // 129 for the value plus the 8 gap to its neighbour, above the even 120.
      final mix = _cellWidth(tester, '12.1/34.5');
      expect(mix, 137);
      final rest = (480 - mix) / 3;
      expect(_cellWidth(tester, '+ Helium'), closeTo(rest, 0.01));
      expect(_cellWidth(tester, '+95.0'), closeTo(rest, 0.01));
      expect(_cellWidth(tester, '145.0'), closeTo(rest, 0.01));
    });

    testWidgets('a header word no wider than its share does not widen it', (
      tester,
    ) async {
      await _pump(tester, width: 480);

      expect(
        tester.getSize(find.text('Pressure\n(bar)')).width,
        _cellWidth(tester, '145.0'),
      );
    });

    testWidgets('data rows stay on one line and scale to a width too narrow '
        'for them', (tester) async {
      await _pump(tester, width: 320);
      expect(tester.takeException(), isNull);

      // Minimums of 114, 80, 100 and 137 are 431 in 320: everything shrinks by
      // the same factor rather than clipping a pressure or wrapping a row.
      final mix = find.text('12.1/34.5');
      expect(tester.widget<Text>(mix).softWrap, isFalse);
      expect(tester.getRect(mix).right, closeTo(320, 0.01));
      expect(tester.getRect(mix).width, closeTo(137 * 320 / 431, 0.01));
      expect(tester.getRect(find.text('+ Helium')).left, 0);
    });

    testWidgets('large text measures at its scaled size', (tester) async {
      await _pump(tester, width: 480, textScale: 1.5);
      expect(tester.takeException(), isNull);

      // 192 for the value at 1.5x plus the gap, which an unscaled measurement
      // would have put at 137 with the text running out of its column.
      expect(_cellWidth(tester, '12.1/34.5'), 200);
      expect(tester.getRect(find.text('12.1/34.5')).right, closeTo(480, 0.01));
    });

    testWidgets('a right-to-left locale mirrors the columns', (tester) async {
      await _pump(tester, width: 320, locale: const Locale('he'));
      expect(tester.takeException(), isNull);

      final mix = tester.getRect(find.text('12.1/34.5'));
      final pressure = tester.getRect(find.text('145.0'));
      expect(mix.right, lessThanOrEqualTo(pressure.left));
      expect(mix.left, greaterThanOrEqualTo(0));
    });
  });
}
