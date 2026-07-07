import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';

OcrTextBlock block(String text) =>
    OcrTextBlock(text: text, boundingBox: const Rect.fromLTWH(0, 0, 50, 10));

const metric = UnitDefaults(
  depthFeet: false,
  pressurePsi: false,
  tempFahrenheit: false,
  weightLbs: false,
);

void main() {
  test('explicit ft token flips depth to feet', () {
    final units = inferPageUnits([block('60 ft'), block('69')], metric);
    expect(units.depthFeet, isTrue);
  });

  test('explicit imperial context flips temperature too', () {
    // A psi page with bare temps is a US log: 73 means Fahrenheit.
    final units = inferPageUnits([block('3000 psi')], metric);
    expect(units.pressurePsi, isTrue);
    expect(units.tempFahrenheit, isTrue);
  });

  test('metric tokens keep metric', () {
    final units = inferPageUnits(
      [block('11.1m'), block('200 bar')],
      const UnitDefaults(
        depthFeet: true,
        pressurePsi: true,
        tempFahrenheit: true,
        weightLbs: true,
      ),
    );
    expect(units.depthFeet, isFalse);
    expect(units.pressurePsi, isFalse);
  });

  test('ambiguous printed hints do not vote', () {
    final units = inferPageUnits([
      block('5m/15ft stop'),
      block('bar/psi'),
    ], metric);
    expect(units.depthFeet, isFalse);
    expect(units.pressurePsi, isFalse);
  });

  test('no tokens falls back to settings', () {
    final units = inferPageUnits([block('69'), block('32')], metric);
    expect(units.depthFeet, isFalse);
    expect(units.tempFahrenheit, isFalse);
  });
}
