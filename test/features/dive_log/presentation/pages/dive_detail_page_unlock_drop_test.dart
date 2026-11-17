import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_media_card_editor.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The dive page tells a drop which sitting is open, and how to show the
/// Media card for it (issue #4527, plan 6).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  OpenDiveSitting? openSitting(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      ).read(openDiveSittingProvider);

  testWidgets('locked: none; unlocked: this dive; Cancel: none again', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(openSitting(tester), isNull);

    await unlock(tester);
    final open = openSitting(tester);
    expect(open?.diveId, dive.id);
    expect(open?.session.isDisposed, isFalse);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(openSitting(tester), isNull);
  });

  testWidgets('showing the Media card for a drop opens its editor, even '
      'where the diver hides it', (tester) async {
    await pumpPage(tester, visible: const {DiveDetailSectionId.notes});
    await unlock(tester);
    expect(find.byType(DiveMediaCardEditor), findsNothing);

    openSitting(tester)!.showMediaCard();
    await settle(tester);
    expect(find.byType(DiveMediaCardEditor), findsOneWidget);
  });

  testWidgets('leaving the page: none', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );
    page.router.go('/home');
    await settle(tester);
    expect(container.read(openDiveSittingProvider), isNull);
  });
}
