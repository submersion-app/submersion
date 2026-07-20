import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';

void main() {
  test('layout providers default to expanded panes, Plan tab, no focus', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(editorPaneCollapsedProvider), isFalse);
    expect(container.read(resultsPaneCollapsedProvider), isFalse);
    expect(container.read(resultsPaneNarrowExpandedProvider), isFalse);
    expect(container.read(plannerPhoneTabProvider), 0);
    expect(container.read(setupFocusSectionProvider), isNull);
  });

  test('providers hold written state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editorPaneCollapsedProvider.notifier).state = true;
    container.read(plannerPhoneTabProvider.notifier).state = 3;
    container.read(setupFocusSectionProvider.notifier).state = 'gas';
    expect(container.read(editorPaneCollapsedProvider), isTrue);
    expect(container.read(plannerPhoneTabProvider), 3);
    expect(container.read(setupFocusSectionProvider), 'gas');
  });
}
