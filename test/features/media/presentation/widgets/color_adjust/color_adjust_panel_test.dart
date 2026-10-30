import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';

import 'color_adjust_test_support.dart';

/// Issue #3520: the Adjust color panel in the viewers.
void main() {
  late FakeColorRepository repo;

  setUp(() => repo = FakeColorRepository());

  Future<ProviderContainerHandle> pump(
    WidgetTester tester, {
    ColorAdjustment? adjustment,
    String? diveId = 'd1',
    bool diverAuto = false,
    bool pickWhiteAvailable = true,
    Axis layout = Axis.horizontal,
  }) async {
    final container = colorContainer(repo, diverAuto: diverAuto);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var done = 0;
    var picked = 0;
    await tester.pumpWidget(
      colorHost(
        container,
        SingleChildScrollView(
          child: ColorAdjustPanel(
            item: colorItem(diveId: diveId, adjustment: adjustment),
            onDone: () => done++,
            onPickWhite: () => picked++,
            pickWhiteAvailable: pickWhiteAvailable,
            layout: layout,
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderContainerHandle(container, () => done, () => picked);
  }

  testWidgets('dragging Warmth draws live and saves once on release', (
    tester,
  ) async {
    final h = await pump(tester);
    final slider = find.byKey(const Key('color_slider_warmth'));
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    final draft = h.container.read(colorAdjustmentDraftNotifierProvider('m1'));
    expect(draft!.warmth, greaterThan(0));
    expect(repo.saves, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.saves, hasLength(1));
    expect(repo.saves.single.$1, 'm1');
    expect(repo.saves.single.$2!.warmth, greaterThan(0));
  });

  testWidgets('Strength is disabled with no automatic fix or white point', (
    tester,
  ) async {
    await pump(tester);
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('color_slider_strength')))
          .onChanged,
      isNull,
    );
  });

  testWidgets('Strength is enabled when the automatic fix applies', (
    tester,
  ) async {
    await pump(tester, diverAuto: true);
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('color_slider_strength')))
          .onChanged,
      isNotNull,
    );
  });

  testWidgets('Auto on while the diver switch is off saves an override', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Auto'));
    await tester.pumpAndSettle();
    expect(repo.saves.single.$2, const ColorAdjustment(autoOverride: true));
  });

  testWidgets('Auto back to the diver default clears the override', (
    tester,
  ) async {
    await pump(
      tester,
      adjustment: const ColorAdjustment(autoOverride: true, warmth: 0.2),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Auto'));
    await tester.pumpAndSettle();
    expect(repo.saves.single.$2, const ColorAdjustment(warmth: 0.2));
  });

  testWidgets('Reset saves no adjustment', (tester) async {
    await pump(tester, adjustment: const ColorAdjustment(warmth: 0.5));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(repo.saves.single, ('m1', null));
  });

  testWidgets('Apply to this dive is hidden for media on no dive', (
    tester,
  ) async {
    await pump(tester, diveId: null);
    expect(find.text('Apply to this dive'), findsNothing);
  });

  testWidgets('holding Original peeks and releases', (tester) async {
    final h = await pump(tester, adjustment: const ColorAdjustment(tint: 0.3));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Original')),
    );
    await tester.pump();
    expect(h.container.read(colorPeekOriginalNotifierProvider), 'm1');
    await gesture.up();
    await tester.pump();
    expect(h.container.read(colorPeekOriginalNotifierProvider), isNull);
  });

  testWidgets('Pick white and Done call back', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.text('Pick white'));
    await tester.tap(find.text('Done'));
    expect(h.picked(), 1);
    expect(h.done(), 1);
  });

  testWidgets('Pick white is hidden where it is not available', (tester) async {
    await pump(tester, pickWhiteAvailable: false);
    expect(find.text('Pick white'), findsNothing);
  });

  testWidgets('the tone sliders sit under More, open when docked', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('color_slider_contrast')), findsNothing);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('color_slider_contrast')), findsOneWidget);
  });

  testWidgets('docked, the tone sliders start open', (tester) async {
    await pump(tester, layout: Axis.vertical);
    expect(find.byKey(const Key('color_slider_brightness')), findsOneWidget);
  });

  testWidgets('a failed save says so', (tester) async {
    repo.failSave = true;
    await pump(tester, adjustment: const ColorAdjustment(warmth: 0.5));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save the color adjustment"), findsOneWidget);
  });
}

class ProviderContainerHandle {
  ProviderContainerHandle(this.container, this.done, this.picked);
  final ProviderContainer container;
  final int Function() done;
  final int Function() picked;
}
