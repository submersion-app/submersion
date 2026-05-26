import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_match_review_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';

/// Seeds review state without running the async matcher (autoInit:false), and
/// sets the protected `state` from inside a subclass to avoid the
/// invalid_use_of_protected_member lint.
class _SeededNotifier extends SiteMatchReviewNotifier {
  _SeededNotifier(Ref ref, SiteMatchReviewState seeded)
    : super(ref, null, autoInit: false) {
    state = seeded;
  }
}

void main() {
  testWidgets('renders summary and an auto-matched row', (tester) async {
    final dive = Dive(
      id: 'd1',
      diveNumber: 7,
      dateTime: DateTime(2026, 1, 1),
      maxDepth: 18,
    );
    final seeded = SiteMatchReviewState(
      isLoading: false,
      entries: [
        DiveMatchEntry(
          dive: dive,
          status: MatchEntryStatus.autoMatched,
          siteId: 's1',
          siteName: 'Blue Hole',
          distanceMeters: 42,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siteMatchReviewProvider(
            null,
          ).overrideWith((ref) => _SeededNotifier(ref, seeded)),
        ],
        child: const MaterialApp(home: SiteMatchReviewPage()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('1 matched'), findsOneWidget);
    expect(find.text('Blue Hole · 42 m'), findsOneWidget);
    expect(find.text('Unlink'), findsOneWidget);
  });
}
