import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_routes.dart';

/// The old dive centre edit addresses open the page unlocked once phase 3's
/// switch is on, and keep the form until then (issue #4527).
void main() {
  test('the edit address opens the page unlocked with the switch on', () {
    expect(
      diveCenterEditLocation('doc', unlockEditing: true),
      '/dive-centers/doc?mode=edit',
    );
    expect(diveCenterEditLocation('doc', unlockEditing: false), isNull);
  });

  test('a page moving into the pane keeps asking to unlock', () {
    expect(
      diveCenterPaneLocation('doc', openUnlocked: true),
      '/dive-centers?selected=doc&mode=edit',
    );
    expect(
      diveCenterPaneLocation('doc', openUnlocked: false),
      '/dive-centers?selected=doc',
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
          on = diveCenterEditPane(
            context,
            'doc',
            (_) {},
            () {},
            onDeleted: deleted,
            unlockEditing: true,
          );
          off = diveCenterEditPane(
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

    expect(on, isA<DiveCenterDetailPage>());
    expect((on as DiveCenterDetailPage).openUnlocked, isTrue);
    expect((on as DiveCenterDetailPage).onDeleted, equals(deleted));
    expect(off, isA<DiveCenterEditPage>());
  });
}
