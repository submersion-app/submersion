import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/apply_to_dive_action.dart';

import 'color_adjust_test_support.dart';

/// Issue #3520: "Apply to this dive" asks first and can be undone.
void main() {
  late FakeColorRepository repo;
  const source = ColorAdjustment(warmth: 0.4, autoOverride: true);

  setUp(() => repo = FakeColorRepository());

  Future<void> pump(WidgetTester tester) async {
    final container = colorContainer(repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      colorHost(
        container,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => runApplyToDive(context, ref, colorItem(), source),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('the confirmation says how many will change', (tester) async {
    await pump(tester);
    expect(find.text('Apply to this dive?'), findsOneWidget);
    expect(
      find.textContaining('3 other photos and videos will use these'),
      findsOneWidget,
    );
  });

  testWidgets('cancel writes nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.applies, isEmpty);
  });

  testWidgets('apply writes, and Undo restores the prior values', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repo.applies.single, ('d1', 'm1', source));
    expect(find.text('Updated 3 photos and videos'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.restores.single, repo.prior);
  });

  testWidgets('no other media on the dive asks nothing', (tester) async {
    repo.siblings = 0;
    await pump(tester);
    expect(find.text('Apply to this dive?'), findsNothing);
    expect(repo.applies, isEmpty);
  });
}
