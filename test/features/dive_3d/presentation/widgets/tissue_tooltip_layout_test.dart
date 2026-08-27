import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_tooltip_layout.dart';

void main() {
  group('TissueTooltipLayoutDelegate', () {
    test('positions just below-right of the anchor when it fits', () {
      const d = TissueTooltipLayoutDelegate(Offset(100, 80));
      final pos = d.getPositionForChild(
        const Size(400, 300),
        const Size(220, 60),
      );
      expect(pos, const Offset(114, 94)); // anchor + gap(14)
    });

    test('clamps against the REAL child height so a tall tooltip stays '
        'on-screen (the fixed-60 estimate would have overflowed)', () {
      // Anchor near the bottom-right; a localized/large-text tooltip is 120 tall.
      const d = TissueTooltipLayoutDelegate(Offset(390, 290));
      final pos = d.getPositionForChild(
        const Size(400, 300),
        const Size(220, 120),
      );
      // maxTop = 300 - 120 = 180 (not 300 - 60 = 240, which would spill 60px).
      expect(pos, const Offset(180, 180));
    });

    test('never goes negative when the child is larger than the viewport', () {
      const d = TissueTooltipLayoutDelegate(Offset(10, 10));
      final pos = d.getPositionForChild(
        const Size(200, 100),
        const Size(220, 140), // taller and wider than the viewport
      );
      expect(pos, Offset.zero);
    });

    test(
      'caps width at maxWidth but narrows to the viewport on tiny panes',
      () {
        const d = TissueTooltipLayoutDelegate(Offset.zero, maxWidth: 220);
        final wide = d.getConstraintsForChild(
          const BoxConstraints(maxWidth: 400, maxHeight: 300),
        );
        expect(wide.minWidth, 220);
        expect(wide.maxWidth, 220);
        final narrow = d.getConstraintsForChild(
          const BoxConstraints(maxWidth: 150, maxHeight: 300),
        );
        expect(narrow.minWidth, 150);
        expect(narrow.maxWidth, 150);
      },
    );

    test('relayouts only when the anchor or maxWidth changes', () {
      const a = TissueTooltipLayoutDelegate(Offset(10, 10));
      const same = TissueTooltipLayoutDelegate(Offset(10, 10));
      const moved = TissueTooltipLayoutDelegate(Offset(11, 10));
      expect(a.shouldRelayout(same), isFalse);
      expect(a.shouldRelayout(moved), isTrue);
    });
  });
}
