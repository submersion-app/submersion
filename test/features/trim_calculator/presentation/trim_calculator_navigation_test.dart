import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/router/nav_shortcut_pages.dart';
import 'package:submersion/features/trim_calculator/presentation/pages/trim_calculator_page.dart';
import 'package:submersion/features/trim_calculator/presentation/trim_calculator_navigation.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

/// Where the trim calculator lives (issue #5028).
void main() {
  test('without a dive, the bare tool path', () {
    expect(trimCalculatorLocation(), '/planning/trim-calculator');
  });

  test('a dive rides in ?dive=, encoded', () {
    final uri = Uri.parse(trimCalculatorLocation(diveId: 'a b&c'));
    expect(uri.path, '/planning/trim-calculator');
    expect(uri.queryParameters[kTrimCalculatorDiveParam], 'a b&c');
  });

  test('it can be pinned as a nav shortcut beside the other tools', () {
    final shortcut = kNavShortcuts.singleWhere(
      (s) => s.id == kTrimCalculatorToolId,
    );
    expect(shortcut.group, NavShortcutGroup.planning);
    expect(
      kNavShortcutPages[kTrimCalculatorToolId]!(const {}),
      isA<TrimCalculatorPage>(),
    );
  });
}
