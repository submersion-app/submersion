import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/presentation/helpers/color_pick_white.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';

import '../widgets/color_adjust/color_adjust_test_support.dart';

/// Issue #3520: a picked white point is drawn only once it is saved.
void main() {
  Future<ProviderContainer> pick(
    WidgetTester tester,
    FakeColorRepository repo, {
    ColorAdjustment? draft,
  }) async {
    final container = colorContainer(repo);
    addTearDown(container.dispose);
    // The panel's live draft, held the way the panel holds it.
    final sub = container.listen(
      colorAdjustmentDraftNotifierProvider('m1'),
      (_, _) {},
    );
    addTearDown(sub.close);
    if (draft != null) {
      container
          .read(colorAdjustmentDraftNotifierProvider('m1').notifier)
          .set(draft);
    }
    await tester.pumpWidget(
      colorHost(
        container,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => applyPickedWhite(
              context,
              ref,
              colorItem(),
              const WhitePoint(0.3, 0.5, 0.6),
            ),
            child: const Text('pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a saved white point moves the live draft on', (tester) async {
    final repo = FakeColorRepository();
    final container = await pick(
      tester,
      repo,
      draft: const ColorAdjustment(warmth: 0.2),
    );
    expect(repo.saves.single.$2!.whitePoint, const WhitePoint(0.3, 0.5, 0.6));
    expect(
      container.read(colorAdjustmentDraftNotifierProvider('m1')),
      const ColorAdjustment(warmth: 0.2, whitePoint: WhitePoint(0.3, 0.5, 0.6)),
    );
  });

  testWidgets('with no live draft (the panel has let go of the item) none is '
      'left behind', (tester) async {
    // A pick that answers after the panel closed or paged on: a draft set
    // now would never be cleared and would hide every later change.
    final repo = FakeColorRepository();
    final container = await pick(tester, repo);
    expect(repo.saves.single.$2!.whitePoint, const WhitePoint(0.3, 0.5, 0.6));
    expect(container.read(colorAdjustmentDraftNotifierProvider('m1')), isNull);
  });

  testWidgets('a failed save is not left drawn', (tester) async {
    final repo = FakeColorRepository()..failSave = true;
    const before = ColorAdjustment(warmth: 0.2);
    final container = await pick(tester, repo, draft: before);
    expect(find.text("Couldn't save the color adjustment"), findsOneWidget);
    expect(container.read(colorAdjustmentDraftNotifierProvider('m1')), before);
  });
}
