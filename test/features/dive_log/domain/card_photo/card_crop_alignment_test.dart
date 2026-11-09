import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/card_photo/card_crop_alignment.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';

/// A 3:2 landscape photo on a 4:1 card shows 3/8 of the photo's height.
const _landscape = 1.5;
const _card = 4.0;

void main() {
  group('cardCropAlignmentY', () {
    test('centres when nothing is known about the photo', () {
      expect(cardCropAlignmentY(imageAspect: _landscape, cardAspect: _card), 0);
    });

    test('centres when the photo is wider than the card', () {
      expect(
        cardCropAlignmentY(
          imageAspect: 5,
          cardAspect: _card,
          focusBoxes: const [FocusBox(x: 0.1, y: 0.0, width: 0.2, height: 0.1)],
        ),
        0,
      );
    });

    group('tagged people', () {
      test('centres the strip on a single box', () {
        // Strip is 0.375 tall; a box centred at 0.2 puts the strip top at
        // 0.0125, out of a slack of 0.625.
        final y = cardCropAlignmentY(
          imageAspect: _landscape,
          cardAspect: _card,
          focusBoxes: const [
            FocusBox(x: 0.4, y: 0.15, width: 0.2, height: 0.1),
          ],
        );
        expect(y, closeTo(2 * 0.0125 / 0.625 - 1, 1e-9));
      });

      test('centres on the union of several boxes', () {
        final y = cardCropAlignmentY(
          imageAspect: _landscape,
          cardAspect: _card,
          focusBoxes: const [
            FocusBox(x: 0.1, y: 0.5, width: 0.1, height: 0.1),
            FocusBox(x: 0.7, y: 0.7, width: 0.1, height: 0.1),
          ],
        );
        // Union 0.5..0.8, centre 0.65, strip top 0.4625.
        expect(y, closeTo(2 * 0.4625 / 0.625 - 1, 1e-9));
      });

      test(
        'keeps the top of the people when they span more than the strip',
        () {
          final y = cardCropAlignmentY(
            imageAspect: _landscape,
            cardAspect: _card,
            focusBoxes: const [
              FocusBox(x: 0.2, y: 0.3, width: 0.3, height: 0.6),
            ],
          );
          expect(y, closeTo(2 * 0.3 / 0.625 - 1, 1e-9));
        },
      );

      test('clamps to the bottom edge', () {
        final y = cardCropAlignmentY(
          imageAspect: _landscape,
          cardAspect: _card,
          focusBoxes: const [FocusBox(x: 0.2, y: 0.9, width: 0.1, height: 0.1)],
        );
        expect(y, 1);
      });

      test('wins over the row scores', () {
        final rows = [for (var i = 0; i < 40; i++) i >= 36 ? 1.0 : 0.0];
        final y = cardCropAlignmentY(
          imageAspect: _landscape,
          cardAspect: _card,
          focusBoxes: const [FocusBox(x: 0.4, y: 0.0, width: 0.2, height: 0.1)],
          rowScores: rows,
        );
        expect(y, -1);
      });
    });

    group('row scores', () {
      test('moves the strip to the busy rows', () {
        // 40 rows, strip 15 rows. Detail in rows 0..9 only.
        final rows = [for (var i = 0; i < 40; i++) i < 10 ? 1.0 : 0.05];
        final y = cardCropAlignmentY(
          imageAspect: _landscape,
          cardAspect: _card,
          rowScores: rows,
        );
        expect(y, lessThan(-0.5));
      });

      test('moves the strip down for detail at the bottom', () {
        final rows = [for (var i = 0; i < 40; i++) i >= 30 ? 1.0 : 0.05];
        final y = cardCropAlignmentY(
          imageAspect: _landscape,
          cardAspect: _card,
          rowScores: rows,
        );
        expect(y, greaterThan(0.5));
      });

      test('stays centred on a flat image', () {
        final rows = List.filled(40, 0.3);
        expect(
          cardCropAlignmentY(
            imageAspect: _landscape,
            cardAspect: _card,
            rowScores: rows,
          ),
          0,
        );
      });

      test('stays centred when the best strip only just beats the centre', () {
        // Slightly more detail near the top, well under the required gain.
        final rows = [for (var i = 0; i < 40; i++) i < 15 ? 0.33 : 0.3];
        expect(
          cardCropAlignmentY(
            imageAspect: _landscape,
            cardAspect: _card,
            rowScores: rows,
          ),
          0,
        );
      });

      test('stays centred on an all-black image', () {
        expect(
          cardCropAlignmentY(
            imageAspect: _landscape,
            cardAspect: _card,
            rowScores: List.filled(40, 0.0),
          ),
          0,
        );
      });

      test('stays centred with too few rows', () {
        expect(
          cardCropAlignmentY(
            imageAspect: _landscape,
            cardAspect: _card,
            rowScores: const [1.0],
          ),
          0,
        );
      });

      test('stays within -1..1', () {
        final rows = [for (var i = 0; i < 64; i++) i == 63 ? 5.0 : 0.0];
        final y = cardCropAlignmentY(
          imageAspect: 0.75,
          cardAspect: _card,
          rowScores: rows,
        );
        expect(y, inInclusiveRange(-1, 1));
        expect(y, greaterThan(0.5));
      });
    });
  });
}
