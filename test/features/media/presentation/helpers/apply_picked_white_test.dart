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
    FakeColorRepository repo,
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

  testWidgets('a saved white point is kept', (tester) async {
    final repo = FakeColorRepository();
    final container = await pick(tester, repo);
    expect(repo.saves.single.$2!.whitePoint, const WhitePoint(0.3, 0.5, 0.6));
    expect(container.read(colorAdjustmentDraftProvider('m1')), isNotNull);
  });

  testWidgets('a failed save is not left drawn', (tester) async {
    final repo = FakeColorRepository()..failSave = true;
    final container = await pick(tester, repo);
    expect(find.text("Couldn't save the color adjustment"), findsOneWidget);
    expect(container.read(colorAdjustmentDraftProvider('m1')), isNull);
  });
}
