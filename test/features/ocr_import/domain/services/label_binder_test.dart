import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/label_binder.dart';
import 'package:submersion/features/ocr_import/domain/services/label_definitions.dart';

OcrTextBlock block(
  String text,
  double l,
  double t, {
  double w = 80,
  double h = 12,
}) => OcrTextBlock(text: text, boundingBox: Rect.fromLTWH(l, t, w, h));

void main() {
  group('findLabels', () {
    test('matches common template labels', () {
      final blocks = [
        block('Dive No.', 0, 0),
        block('Date', 200, 0),
        block('Location', 0, 30),
        block('Bottom Time', 100, 300),
      ];
      final labels = findLabels(blocks);
      expect(
        labels.map((l) => l.field),
        containsAll([
          LogField.diveNumber,
          LogField.date,
          LogField.siteName,
          LogField.bottomTime,
        ]),
      );
    });

    test('Certification No. never matches dive number', () {
      final labels = findLabels([block('Certification No.', 0, 900)]);
      expect(labels, isEmpty);
    });

    test('Bottom Time To Date never matches bottom time', () {
      final labels = findLabels([block('Bottom Time To Date', 0, 900)]);
      expect(labels, isEmpty);
    });
  });

  group('bindValue', () {
    test('binds value right of label', () {
      final label = block('Location', 0, 30);
      final value = block("O'ahu - pipe", 100, 30);
      final labels = findLabels([label]);
      final bound = bindValue(
        labels.single,
        [label, value],
        labelBlocks: {label},
      );
      expect(bound?.text, "O'ahu - pipe");
    });

    test('binds value above label (PADI Z-diagram)', () {
      final label = block('DEPTH', 100, 220);
      final value = block('69', 105, 190, w: 30);
      final labels = findLabels([label]);
      final bound = bindValue(
        labels.single,
        [label, value],
        labelBlocks: {label},
      );
      expect(bound?.text, '69');
    });

    test('binds value below label (boxed template)', () {
      final label = block('START (psi)', 100, 100);
      final value = block('2800', 110, 118, w: 40);
      final labels = findLabels([label]);
      final bound = bindValue(
        labels.single,
        [label, value],
        labelBlocks: {label},
      );
      expect(bound?.text, '2800');
    });

    test('never binds another label as a value', () {
      final label = block('Time IN', 0, 100);
      final otherLabel = block('Time OUT', 120, 100);
      final labels = findLabels([label, otherLabel]);
      final timeIn = labels.firstWhere((l) => l.field == LogField.timeIn);
      final bound = bindValue(
        timeIn,
        [label, otherLabel],
        labelBlocks: {label, otherLabel},
      );
      expect(bound, isNull);
    });

    test('ignores values beyond the distance threshold', () {
      final label = block('Weight', 0, 100);
      final farValue = block('11', 0, 600, w: 20);
      final labels = findLabels([label]);
      final bound = bindValue(
        labels.single,
        [label, farValue],
        labelBlocks: {label},
      );
      expect(bound, isNull);
    });
  });
}
