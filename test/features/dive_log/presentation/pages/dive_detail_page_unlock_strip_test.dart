import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

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

  // The card was marked changed on the page. Emptied and closed it goes
  // back to the strip, and the mark goes with it, or nothing on screen
  // says the sitting changed it.
  testWidgets('a changed card back on the strip carries the dot', (
    tester,
  ) async {
    final wreck = Tag(
      id: 'wreck',
      name: 'Wreck',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    await pumpPage(tester, stored: dive.copyWith(tags: [wreck]));
    await unlock(tester);
    final tags = chip(DiveDetailSectionId.tags.name);
    Finder dot() =>
        find.descendant(of: tags, matching: find.byType(RecordChangedDot));
    await tester.tap(find.byTooltip('Edit Tags'));
    await settle(tester);

    tester
        .widget<TagFormBlock>(find.byType(TagFormBlock))
        .onTagsChanged(const []);
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(tags, findsOneWidget);
    expect(dot(), findsOneWidget);
  });
}
