import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/apply_to_dive_action.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'color_adjust_test_support.dart';

/// Issue #3520: "Apply to this dive" asks first, then holds the change in
/// the photo's sitting until Save (issue #4527).
void main() {
  late FakeColorRepository repo;

  setUp(() => repo = FakeColorRepository());

  Future<void> pump(WidgetTester tester, {bool withSitting = true}) async {
    final sitting = withSitting
        ? EditSession<PhotoRecord>(
            PhotoRecord(item: colorItem(), species: const [], people: const []),
          )
        : null;
    if (sitting != null) addTearDown(sitting.dispose);
    final container = colorContainer(repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      colorHost(
        container,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                runApplyToDive(context, ref, colorItem(), sitting: sitting),
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

  testWidgets('Apply holds the change and writes nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repo.applies, isEmpty);
    expect(find.text('Undo'), findsNothing);
  });

  // Held in the photo's sitting only: with none, nothing is asked or
  // written (issue #4527).
  testWidgets('with no sitting it asks nothing and writes nothing', (
    tester,
  ) async {
    await pump(tester, withSitting: false);
    expect(find.text('Apply to this dive?'), findsNothing);
    expect(repo.applies, isEmpty);
  });

  testWidgets('no other media on the dive asks nothing', (tester) async {
    repo.siblings = 0;
    await pump(tester);
    expect(find.text('Apply to this dive?'), findsNothing);
    expect(repo.applies, isEmpty);
  });
}
