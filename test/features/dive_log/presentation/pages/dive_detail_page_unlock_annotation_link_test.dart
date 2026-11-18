import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// An annotation link in the Notes card of a dive with no profile has no
/// marker to open. On a page that locks, the link is not a way to change
/// the annotation: that is the open Profile or Notes card's (issue #4527,
/// plan 6, Task 11).
void main() {
  late Dive linked;

  setUp(() async {
    await setUpTestDatabase();
    // No profile, so the link has no marker to open.
    await DiveRepository().createDive(dive.copyWith(notes: ''));
    await AnnotationRepository().addAnnotation(
      diveId: dive.id,
      timestamp: 120,
      words: 'Turtle here',
    );
    linked = (await DiveRepository().getDiveById(dive.id))!;
  });
  tearDown(tearDownTestDatabase);

  Future<int> storedTime() async =>
      (await AnnotationRepository().annotationsForDive(
        dive.id,
      )).single.timestamp;

  for (final unlocked in [false, true]) {
    testWidgets(
      '${unlocked ? 'unlocked, Notes closed' : 'locked'}: the link opens no '
      'time sheet',
      (tester) async {
        await pumpPage(
          tester,
          stored: linked,
          visible: const {DiveDetailSectionId.notes},
        );
        if (unlocked) await unlock(tester);
        await tester.tapOnText(find.textRange.ofSubstring('Turtle here'));
        await settle(tester);

        expect(find.byType(BottomSheet), findsNothing);
        expect(await tester.runAsync(storedTime), 120);
      },
    );
  }
}
