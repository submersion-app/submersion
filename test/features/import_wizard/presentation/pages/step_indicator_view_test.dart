import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/presentation/pages/step_indicator_view.dart';

void main() {
  const acquisition = ['File', 'Source', 'Map', 'Divers', 'Photos'];
  const trailing = ['Review', 'Import', 'Done'];

  test('shows every step when none is hidden', () {
    final view = stepIndicatorView(
      acquisitionLabels: acquisition,
      hidden: const [false, false, false, false, false],
      trailingLabels: trailing,
      currentPage: 2,
    );
    expect(view.labels, [...acquisition, ...trailing]);
    expect(view.current, 2);
  });

  test('leaves hidden steps out and moves the current dot with them', () {
    final view = stepIndicatorView(
      acquisitionLabels: acquisition,
      hidden: const [false, false, true, true, false],
      trailingLabels: trailing,
      currentPage: 4,
    );
    expect(view.labels, ['File', 'Source', 'Photos', ...trailing]);
    expect(view.current, 2);
  });

  test('the current step shows even when it would be hidden', () {
    final view = stepIndicatorView(
      acquisitionLabels: acquisition,
      hidden: const [false, false, false, true, true],
      trailingLabels: trailing,
      currentPage: 3,
    );
    expect(view.labels, ['File', 'Source', 'Map', 'Divers', ...trailing]);
    expect(view.current, 3);
  });

  test('pages past the acquisition steps count from the shown ones', () {
    final view = stepIndicatorView(
      acquisitionLabels: acquisition,
      hidden: const [false, false, true, true, true],
      trailingLabels: trailing,
      // Review: the page right after the five acquisition pages.
      currentPage: 5,
    );
    expect(view.labels, ['File', 'Source', ...trailing]);
    expect(view.current, 2);
  });
}
