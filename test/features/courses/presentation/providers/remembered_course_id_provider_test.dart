import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';

/// The course a list returned to reopens: its last-opened one, while the
/// list still shows it (#3301).
void main() {
  AsyncValue<String?> remembered(String? highlighted) {
    final container = ProviderContainer(
      overrides: [
        filteredCoursesProvider.overrideWithValue(
          AsyncData([
            Course(
              id: 'r1',
              diverId: 'diver-1',
              name: 'Open Water',
              agency: 'padi',
              startDate: DateTime(2024, 1, 10),
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(highlightedCourseIdProvider.notifier).state = highlighted;
    return container.read(rememberedCourseIdProvider);
  }

  test('a listed course is remembered', () {
    expect(remembered('r1'), const AsyncData<String?>('r1'));
  });

  test('a course the list does not show is not', () {
    expect(remembered('gone'), const AsyncData<String?>(null));
  });
}
