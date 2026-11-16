import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/utils/chart_drag_crossing.dart';

void main() {
  group('isDragCrossing', () {
    test('a hover crossing the edge is not a drag', () {
      expect(isDragCrossing(const PointerExitEvent()), isFalse);
    });

    test('any held button makes it a drag', () {
      expect(
        isDragCrossing(const PointerExitEvent(buttons: kPrimaryButton)),
        isTrue,
      );
      expect(
        isDragCrossing(const PointerEnterEvent(buttons: kSecondaryButton)),
        isTrue,
      );
    });
  });

  group('crossesChartEdgeMidDrag', () {
    test('an exit or enter with a button held', () {
      expect(
        crossesChartEdgeMidDrag(
          const FlPointerExitEvent(PointerExitEvent(buttons: kPrimaryButton)),
        ),
        isTrue,
      );
      expect(
        crossesChartEdgeMidDrag(
          const FlPointerEnterEvent(PointerEnterEvent(buttons: kPrimaryButton)),
        ),
        isTrue,
      );
    });

    test('an exit or enter with no button held', () {
      expect(
        crossesChartEdgeMidDrag(const FlPointerExitEvent(PointerExitEvent())),
        isFalse,
      );
      expect(
        crossesChartEdgeMidDrag(const FlPointerEnterEvent(PointerEnterEvent())),
        isFalse,
      );
    });

    test('every other event, pressed or not', () {
      expect(
        crossesChartEdgeMidDrag(
          const FlPointerHoverEvent(PointerHoverEvent(buttons: kPrimaryButton)),
        ),
        isFalse,
      );
      expect(crossesChartEdgeMidDrag(FlPanEndEvent(DragEndDetails())), isFalse);
    });
  });
}
