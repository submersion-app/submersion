import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_routes.dart';

/// The old course edit addresses open the page unlocked (issue #4527).
void main() {
  test('the edit address opens the page unlocked', () {
    expect(courseEditLocation('k1'), '/courses/k1?mode=edit');
  });

  testWidgets('the pane opens the page unlocked', (tester) async {
    void deleted() {}
    late Widget on;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          on = courseEditPane(context, 'k1', (_) {}, () {}, onDeleted: deleted);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(on, isA<CourseDetailPage>());
    expect((on as CourseDetailPage).openUnlocked, isTrue);
    expect((on as CourseDetailPage).embedded, isTrue);
    expect((on as CourseDetailPage).onDeleted, equals(deleted));
  });
}
