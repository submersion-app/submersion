import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'color_adjust_test_support.dart';

/// Issue #3520: the Adjust color panel in the viewers. Every change is held
/// in the photo's sitting until Save (issue #4527).
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
    bool withSitting = true,
  }) async {
    final item = colorItem(diveId: diveId, adjustment: adjustment);
    final sitting = withSitting
        ? EditSession<PhotoRecord>(
            PhotoRecord(item: item, species: const [], people: const []),
          )
        : null;
    if (sitting != null) addTearDown(sitting.dispose);
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
            item: item,
            sitting: sitting,
            onDone: () => done++,
            onPickWhite: () => picked++,
            pickWhiteAvailable: pickWhiteAvailable,
            layout: layout,
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderContainerHandle(
      container,
      () => done,
      () => picked,
      sitting,
    );
  }

  testWidgets('dragging Warmth draws live and is held on release', (
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
    expect(repo.saves, isEmpty);
    expect(h.held!.warmth, greaterThan(0));
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

  testWidgets('Auto on while the diver switch is off holds an override', (
    tester,
  ) async {
    final h = await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Auto'));
    await tester.pumpAndSettle();
    expect(h.held, const ColorAdjustment(autoOverride: true));
  });

  testWidgets('Auto back to the diver default clears the override', (
    tester,
  ) async {
    final h = await pump(
      tester,
      adjustment: const ColorAdjustment(autoOverride: true, warmth: 0.2),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Auto'));
    await tester.pumpAndSettle();
    expect(h.held, const ColorAdjustment(warmth: 0.2));
  });

  testWidgets('Reset holds no adjustment', (tester) async {
    final h = await pump(
      tester,
      adjustment: const ColorAdjustment(warmth: 0.5),
    );
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(h.held, isNull);
    expect(h.sitting!.isDirty, isTrue);
    expect(repo.saves, isEmpty);
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

  // A photo's colour changes only in its sitting: with none (it ended, or
  // a device that cannot unlock) the panel writes nothing and draws nothing.
  testWidgets('with no sitting a change is neither written nor drawn', (
    tester,
  ) async {
    final h = await pump(
      tester,
      adjustment: const ColorAdjustment(warmth: 0.5),
      withSitting: false,
    );
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(repo.saves, isEmpty);
    expect(
      h.container.read(colorAdjustmentDraftNotifierProvider('m1')),
      isNull,
    );
  });
}

class ProviderContainerHandle {
  ProviderContainerHandle(this.container, this.done, this.picked, this.sitting);
  final ProviderContainer container;
  final int Function() done;
  final int Function() picked;
  final EditSession<PhotoRecord>? sitting;

  /// The colour the sitting holds.
  ColorAdjustment? get held => sitting!.valueOf(photoColorField);
}
