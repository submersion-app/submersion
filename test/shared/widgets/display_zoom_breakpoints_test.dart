import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

Future<bool> _isMasterDetailAt(WidgetTester tester, double zoom) async {
  late bool result;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1000, 800)),
        child: DisplayZoomScope(
          zoom: zoom,
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.isMasterDetail(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );

  return result;
}

void main() {
  testWidgets('a 1000pt viewport is not master-detail at 100%', (tester) async {
    expect(await _isMasterDetailAt(tester, DisplayZoom.defaultValue), isFalse);
  });

  testWidgets('zooming out unlocks master-detail on the same viewport', (
    tester,
  ) async {
    // 1000 / 0.85 = 1176pt, past the 1100pt master-detail breakpoint.
    expect(await _isMasterDetailAt(tester, 0.85), isTrue);
  });

  testWidgets('zooming in can drop below the desktop breakpoint', (
    tester,
  ) async {
    // 1000 / 1.4 = 714pt, below the 800pt desktop breakpoint.
    late bool isMobile;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1000, 800)),
          child: DisplayZoomScope(
            zoom: DisplayZoom.max,
            child: Builder(
              builder: (context) {
                isMobile = ResponsiveBreakpoints.isMobile(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(isMobile, isTrue);
  });
}
