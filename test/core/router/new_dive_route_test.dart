import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/router/app_router.dart' show newDivePage;
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_create_builder.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';

/// `/dives/new` and the list pane's new dive open the dive page while it is
/// being created (issue #4527, plans 8 and 11).
void main() {
  Future<Widget> built(
    WidgetTester tester,
    String location, {
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
            page = newDivePage(state);
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    return page!;
  }

  testWidgets('the dive page is created with the request', (tester) async {
    const prefill = DivePrefill(notes: 'From the log');
    final page = await built(
      tester,
      '/dives/new?tripId=t9&tripCylinderId=c9',
      extra: prefill,
    );

    expect(page, isA<DiveDetailPage>());
    final dive = page as DiveDetailPage;
    expect(dive.newDiveRequest?.prefill, same(prefill));
    expect(dive.newDiveRequest?.tripId, 't9');
    expect(dive.newDiveRequest?.tripCylinderId, 'c9');
  });

  testWidgets('the pane builder opens the dive page being created', (
    tester,
  ) async {
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

    final built = newDivePaneBuilder()(context, saved.add, () => cancelled++);
    expect(built, isA<DiveDetailPage>());
    final page = built as DiveDetailPage;
    expect(page.embedded, isTrue);
    expect(page.newDiveRequest, isNotNull);
    page.onCreated!('d1');
    page.onCreateCancelled!();
    expect(saved, ['d1']);
    expect(cancelled, 1);
  });
}
