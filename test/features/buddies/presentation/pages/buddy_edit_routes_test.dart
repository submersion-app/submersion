import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_routes.dart';

/// The old buddy edit addresses open the page unlocked once phase 3's
/// switch is on, and keep the form until then (issue #4527).
void main() {
  test('the edit address opens the page unlocked with the switch on', () {
    expect(
      buddyEditLocation('doc', unlockEditing: true),
      '/buddies/doc?mode=edit',
    );
    expect(buddyEditLocation('doc', unlockEditing: false), isNull);
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

  testWidgets('the pane opens the page unlocked with the switch on, and the '
      'form without it', (tester) async {
    void deleted() {}
    late Widget on;
    late Widget off;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          on = buddyEditPane(
            context,
            'doc',
            (_) {},
            () {},
            onDeleted: deleted,
            unlockEditing: true,
          );
          off = buddyEditPane(
            context,
            'doc',
            (_) {},
            () {},
            unlockEditing: false,
          );
          return const SizedBox.shrink();
        },
      ),
    );

    expect(on, isA<BuddyDetailPage>());
    expect((on as BuddyDetailPage).openUnlocked, isTrue);
    expect((on as BuddyDetailPage).onDeleted, equals(deleted));
    expect(off, isA<BuddyEditPage>());
  });
}
