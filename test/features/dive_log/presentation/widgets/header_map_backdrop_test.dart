import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';

const _fade = Color(0xFF101418);
const _mapKey = ValueKey('map');

Future<void> _pump(WidgetTester tester, double height) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 200,
          height: height,
          child: const HeaderMapBackdrop(
            fadeColor: _fade,
            child: SizedBox.expand(key: _mapKey),
          ),
        ),
      ),
    ),
  );
}

RenderClipRect _mapClipRender(WidgetTester tester) {
  return tester.renderObject<RenderClipRect>(
    find.ancestor(of: find.byKey(_mapKey), matching: find.byType(ClipRect)),
  );
}

Rect _mapClip(WidgetTester tester) {
  final clip = _mapClipRender(tester);
  return clip.clipper!.getClip(clip.size);
}

LinearGradient _fadeGradient(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(HeaderMapBackdrop),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

void main() {
  testWidgets('map stops short of the bottom edge, under an opaque band', (
    tester,
  ) async {
    await _pump(tester, 200);

    expect(
      _mapClip(tester),
      const Rect.fromLTRB(0, 0, 200, 200 - kHeaderMapBottomInset),
    );

    final gradient = _fadeGradient(tester);
    const opaqueFrom = (200 - kHeaderMapBottomInset) / 200;
    expect(gradient.stops, [
      0.0,
      0.3 * opaqueFrom,
      0.7 * opaqueFrom,
      opaqueFrom,
      1.0,
    ]);
    // Fully opaque from where the map ends to the card's bottom edge.
    expect(gradient.colors.sublist(3), [_fade, _fade]);
    expect(gradient.colors.first, _fade.withValues(alpha: 0.3));
  });

  testWidgets('the map clip only recomputes when the inset changes', (
    tester,
  ) async {
    await _pump(tester, 200);
    final clipper = _mapClipRender(tester).clipper!;
    // The inset is a constant, so a clipper never differs from its
    // predecessor and resizing re-runs getClip without a reclip request.
    expect(clipper.shouldReclip(clipper), isFalse);

    await _pump(tester, 120);
    expect(
      _mapClip(tester),
      const Rect.fromLTRB(0, 0, 200, 120 - kHeaderMapBottomInset),
    );
  });

  testWidgets('a backdrop shorter than the band hides the map entirely', (
    tester,
  ) async {
    await _pump(tester, kHeaderMapBottomInset / 2);

    expect(_mapClip(tester).height, 0);
    expect(_fadeGradient(tester).stops, [0.0, 0.0, 0.0, 0.0, 1.0]);
  });

  Future<int> tapsThroughFade(
    WidgetTester tester, {
    required bool passesPointerThrough,
  }) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: HeaderMapBackdrop(
              fadeColor: _fade,
              passesPointerThrough: passesPointerThrough,
              child: GestureDetector(
                key: _mapKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    // Near the top, where the fade is lightest; the day hero's pins live
    // there, above the header row.
    await tester.tapAt(
      tester.getTopLeft(find.byKey(_mapKey)) + const Offset(20, 20),
    );
    return taps;
  }

  testWidgets('by default the fade takes the tap, as the dive header needs', (
    tester,
  ) async {
    // The dive detail header's InkWell wraps the whole stack; the fade
    // counting as hit is what keeps the map's corner from being a dead zone.
    expect(await tapsThroughFade(tester, passesPointerThrough: false), 0);
  });

  testWidgets('passesPointerThrough lets a tap reach the map under the fade', (
    tester,
  ) async {
    expect(await tapsThroughFade(tester, passesPointerThrough: true), 1);
  });
}
