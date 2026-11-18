import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/helpers/color_pick_white.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/apply_to_dive_action.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'color_adjust_test_support.dart';

/// Adjust color in a photo's sitting (issue #4527): every change is held
/// until Save, Apply to this dive included.
void main() {
  late FakeColorRepository repo;

  setUp(() => repo = FakeColorRepository());

  EditSession<PhotoRecord> sittingOver({ColorAdjustment? adjustment}) {
    final session = EditSession<PhotoRecord>(
      PhotoRecord(
        item: colorItem(adjustment: adjustment),
        species: const [],
        people: const [],
      ),
    );
    addTearDown(session.dispose);
    return session;
  }

  Future<ProviderContainer> pumpPanel(
    WidgetTester tester,
    EditSession<PhotoRecord> sitting,
  ) async {
    final container = colorContainer(repo);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      colorHost(
        container,
        SingleChildScrollView(
          child: ColorAdjustPanel(
            item: sitting.working.item,
            onDone: () {},
            onPickWhite: () {},
            sitting: sitting,
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('a drag draws live and is held on release; nothing written', (
    tester,
  ) async {
    final sitting = sittingOver();
    final container = await pumpPanel(tester, sitting);

    final slider = find.byKey(const Key('color_slider_warmth'));
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(
      container.read(colorAdjustmentDraftNotifierProvider('m1'))!.warmth,
      greaterThan(0),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repo.saves, isEmpty);
    expect(sitting.valueOf(photoColorField)!.warmth, greaterThan(0));
    // The held colour is drawn from the sitting, so no draft is left behind.
    expect(container.read(colorAdjustmentDraftNotifierProvider('m1')), isNull);
  });

  testWidgets('Reset is held as no adjustment', (tester) async {
    final sitting = sittingOver(adjustment: const ColorAdjustment(warmth: 0.5));
    await pumpPanel(tester, sitting);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(repo.saves, isEmpty);
    expect(sitting.valueOf(photoColorField), isNull);
    expect(sitting.isDirty, isTrue);
  });

  group('Pick white', () {
    Future<void> pick(
      WidgetTester tester,
      EditSession<PhotoRecord> sitting,
    ) async {
      final container = colorContainer(repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        colorHost(
          container,
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => applyPickedWhite(
                context,
                ref,
                sitting.stored.item,
                const WhitePoint(0.9, 0.8, 0.7),
                sitting: sitting,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('holds the white point; nothing written', (tester) async {
      final sitting = sittingOver(adjustment: const ColorAdjustment(tint: 0.1));

      await pick(tester, sitting);

      expect(repo.saves, isEmpty);
      expect(
        sitting.valueOf(photoColorField),
        const ColorAdjustment(tint: 0.1, whitePoint: WhitePoint(0.9, 0.8, 0.7)),
      );
    });

    testWidgets('a sample answering after the sitting ended changes nothing', (
      tester,
    ) async {
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: colorItem(), species: const [], people: const []),
      )..dispose();

      await pick(tester, sitting);

      expect(repo.saves, isEmpty);
      expect(sitting.valueOf(photoColorField), isNull);
    });
  });

  group('Apply to this dive', () {
    Future<void> run(WidgetTester tester, EditSession<PhotoRecord> s) async {
      final container = colorContainer(repo);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        colorHost(
          container,
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  runApplyToDive(context, ref, colorItem(), sitting: s),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirms with the count, then holds; no Undo', (tester) async {
      final sitting = sittingOver();
      await run(tester, sitting);
      expect(
        find.textContaining('3 other photos and videos will use these'),
        findsOneWidget,
      );

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(repo.applies, isEmpty);
      expect(find.text('Undo'), findsNothing);
      expect(sitting.isHeld('photo:colorToDive'), isTrue);
      expect(sitting.isDirty, isTrue);
    });

    testWidgets('Cancel holds nothing', (tester) async {
      final sitting = sittingOver();
      await run(tester, sitting);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(sitting.isHeld('photo:colorToDive'), isFalse);
    });
  });
}
