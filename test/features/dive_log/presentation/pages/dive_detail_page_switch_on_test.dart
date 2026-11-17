import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_create_builder.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';

import 'dive_detail_page_unlock_harness.dart';

/// Unlock-to-edit is on in every build: the dive page always offers the
/// lock, and a new dive always opens on the dive page (issue #4527,
/// plan 11).
void main() {
  testWidgets('a dive page built with only its id offers the lock', (
    tester,
  ) async {
    await pumpPage(
      tester,
      initialLocation: '/plain-dive',
      routes: [
        GoRoute(
          path: '/plain-dive',
          builder: (context, state) => DiveDetailPage(diveId: dive.id),
        ),
      ],
    );

    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    // Favourite is a field of the header card, never a toggle in the bar.
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  test('the new dive route always opens the dive page', () {
    final page = newDiveRoutePage();

    expect(page, isA<DiveDetailPage>());
    expect((page as DiveDetailPage).newDiveRequest, isNotNull);
  });
}
