import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Which cards the Add strip offers during a sitting (issue #4527, plan 6).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Finder chip(String cardId) => find.byKey(ValueKey('addStrip_$cardId'));

  testWidgets('a card with nothing to edit until something else exists stays '
      'out of the strip', (tester) async {
    // No buddy and no course: Signatures has nothing to offer.
    await pumpPage(
      tester,
      visible: const {
        DiveDetailSectionId.notes,
        DiveDetailSectionId.signatures,
      },
    );
    await unlock(tester);

    expect(chip(DiveDetailSectionId.signatures.name), findsNothing);
  });

  testWidgets('the same card hidden by the diver is offered, dashed', (
    tester,
  ) async {
    await pumpPage(tester, visible: const {DiveDetailSectionId.notes});
    await unlock(tester);

    expect(chip(DiveDetailSectionId.signatures.name), findsOneWidget);
  });
}
