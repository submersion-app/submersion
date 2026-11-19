import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_routes.dart';

/// The old course edit addresses open the page unlocked once phase 3's
/// switch is on, and keep the form until then (issue #4527).
void main() {
  test('the edit address opens the page unlocked with the switch on', () {
    expect(
      courseEditLocation('k1', unlockEditing: true),
      '/courses/k1?mode=edit',
    );
    expect(courseEditLocation('k1', unlockEditing: false), isNull);
  });

  testWidgets('the pane opens the page unlocked with the switch on, and the '
      'form without it', (tester) async {
    void deleted() {}
    late Widget on;
    late Widget off;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          on = courseEditPane(
            context,
            'k1',
            (_) {},
            () {},
            onDeleted: deleted,
            unlockEditing: true,
          );
          off = courseEditPane(
            context,
            'k1',
            (_) {},
            () {},
            unlockEditing: false,
          );
          return const SizedBox.shrink();
        },
      ),
    );

    expect(on, isA<CourseDetailPage>());
    expect((on as CourseDetailPage).openUnlocked, isTrue);
    expect((on as CourseDetailPage).embedded, isTrue);
    expect((on as CourseDetailPage).onDeleted, equals(deleted));
    expect(off, isA<CourseEditPage>());
  });
}
