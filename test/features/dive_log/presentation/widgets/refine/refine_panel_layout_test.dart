import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_panel.dart';

import 'refine_test_host.dart';

/// The phone sheet keeps its Show button usable: above the soft keyboard
/// and out of the home-indicator zone (review findings on #2773; the old
/// Filter sheet padded for both).
void main() {
  StateProvider<DiveFilterState> target() =>
      StateProvider<DiveFilterState>((ref) => const DiveFilterState());

  testWidgets('the action row stays above the soft keyboard', (tester) async {
    await openRefinePanel(tester, target: target());
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final show = tester.getRect(find.byKey(kRefineApplyKey));
    expect(show.bottom, lessThanOrEqualTo(900 - 400));
  });

  testWidgets('the action row clears the home indicator', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await openRefinePanel(tester, target: target());
    final show = tester.getRect(find.byKey(kRefineApplyKey));
    expect(show.bottom, lessThanOrEqualTo(900 - 34));
  });
}
