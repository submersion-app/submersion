import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// The certification and course list view modes are saved per diver since
/// v262 (issue #2948). Each list's runtime provider seeds from the saved
/// value once, like the other lists, so the list menu can override it for
/// the session.
void main() {
  ProviderContainer containerWith(MockSettingsNotifier notifier) {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('both list providers seed from the saved settings', () {
    final container = containerWith(
      MockSettingsNotifier(
        const AppSettings(
          certificationListViewMode: ListViewMode.table,
          courseListViewMode: ListViewMode.table,
        ),
      ),
    );
    expect(
      container.read(certificationListViewModeProvider),
      ListViewMode.table,
    );
    expect(container.read(courseListViewModeProvider), ListViewMode.table);
  });

  test(
    'the list choice is saved and survives an unrelated settings write',
    () async {
      // The list toggle saves the view mode for the diver (issue #3748); a
      // change to another list's setting leaves it alone.
      final notifier = MockSettingsNotifier();
      final container = containerWith(notifier);
      await notifier.setCertificationListViewMode(ListViewMode.table);
      await notifier.setCourseListViewMode(ListViewMode.table);

      await notifier.setTripListViewMode(ListViewMode.compact);

      expect(
        container.read(certificationListViewModeProvider),
        ListViewMode.table,
      );
      expect(container.read(courseListViewModeProvider), ListViewMode.table);
      expect(notifier.state.certificationListViewMode, ListViewMode.table);
      expect(notifier.state.courseListViewMode, ListViewMode.table);
    },
  );
}
