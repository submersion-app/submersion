import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/router/app_router.dart' show newDivePage;
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_create_builder.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';

/// `/dives/new` and the list pane's new dive open the dive page while it is
/// being created, behind the build switch, and the old form without it
/// (issue #4527, plan 8).
void main() {
  Future<Widget> built(
    WidgetTester tester,
    String location, {
    required bool unlockEditing,
    Object? extra,
  }) async {
    Widget? page;
    final router = GoRouter(
      initialLocation: location,
      initialExtra: extra,
      routes: [
        GoRoute(
          path: '/dives/new',
          builder: (context, state) {
            page = newDivePage(state, unlockEditing: unlockEditing);
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    return page!;
  }

  testWidgets('with the switch, the dive page is created with the request', (
    tester,
  ) async {
    const prefill = DivePrefill(notes: 'From the log');
    final page = await built(
      tester,
      '/dives/new?tripId=t9&tripCylinderId=c9',
      unlockEditing: true,
      extra: prefill,
    );

    expect(page, isA<DiveDetailPage>());
    final dive = page as DiveDetailPage;
    expect(dive.unlockEditing, isTrue);
    expect(dive.newDiveRequest?.prefill, same(prefill));
    expect(dive.newDiveRequest?.tripId, 't9');
    expect(dive.newDiveRequest?.tripCylinderId, 'c9');
  });

  testWidgets('without it, the form, with the trip and slot', (tester) async {
    final page = await built(
      tester,
      '/dives/new?tripId=t9&tripCylinderId=c9',
      unlockEditing: false,
    );

    expect(page, isA<DiveEditPage>());
    expect((page as DiveEditPage).tripId, 't9');
    expect(page.tripCylinderId, 'c9');
  });

  testWidgets('the pane builder follows the switch', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
    final saved = <String>[];
    var cancelled = 0;

    final on = newDivePaneBuilder(unlockEditing: true)(
      context,
      saved.add,
      () => cancelled++,
    );
    expect(on, isA<DiveDetailPage>());
    final page = on as DiveDetailPage;
    expect(page.embedded, isTrue);
    expect(page.newDiveRequest, isNotNull);
    page.onCreated!('d1');
    page.onCreateCancelled!();
    expect(saved, ['d1']);
    expect(cancelled, 1);

    final off = newDivePaneBuilder(unlockEditing: false)(
      context,
      saved.add,
      () => cancelled++,
    );
    expect(off, isA<DiveEditPage>());
    expect((off as DiveEditPage).embedded, isTrue);
  });
}
