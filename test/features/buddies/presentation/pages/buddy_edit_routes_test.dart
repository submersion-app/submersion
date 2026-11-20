import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_routes.dart';

/// The old buddy edit addresses open the page unlocked (issue #4527).
void main() {
  test('the edit address opens the page unlocked', () {
    expect(buddyEditLocation('doc'), '/buddies/doc?mode=edit');
  });

  test('a page moving into the pane keeps asking to unlock', () {
    expect(
      buddyPaneLocation('doc', openUnlocked: true),
      '/buddies?selected=doc&mode=edit',
    );
    expect(
      buddyPaneLocation('doc', openUnlocked: false),
      '/buddies?selected=doc',
    );
  });

  testWidgets('the pane opens the page unlocked', (tester) async {
    void deleted() {}
    late Widget on;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          on = buddyEditPane(context, 'doc', (_) {}, () {}, onDeleted: deleted);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(on, isA<BuddyDetailPage>());
    expect((on as BuddyDetailPage).openUnlocked, isTrue);
    expect((on as BuddyDetailPage).onDeleted, equals(deleted));
  });
}
