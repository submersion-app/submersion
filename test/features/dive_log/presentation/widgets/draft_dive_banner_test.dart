import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draft_dive_banner.dart';

import '../../../../helpers/test_app.dart';

/// The banner above a draft's detail page (issue #637): how long the taps
/// say the dive took, and the ways to finish it.
void main() {
  final closed = Dive(
    id: 'draft',
    dateTime: DateTime(2026, 7, 17, 10),
    entryTime: DateTime(2026, 7, 17, 10),
    exitTime: DateTime(2026, 7, 17, 10, 52),
    isDraft: true,
  );
  final open = Dive(
    id: 'open',
    dateTime: DateTime(2026, 7, 17, 10),
    entryTime: DateTime(2026, 7, 17, 10),
    isDraft: true,
  );

  Future<List<String>> pump(
    WidgetTester tester,
    Dive dive, {
    bool withSurfaced = true,
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SingleChildScrollView(
          child: DraftDiveBanner(
            dive: dive,
            onMarkComplete: () => calls.add('complete'),
            onDownload: () => calls.add('download'),
            onSurfaced: withSurfaced ? () => calls.add('surfaced') : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('a closed draft shows the estimate from its taps', (
    tester,
  ) async {
    await pump(tester, closed);

    expect(find.text('Waiting for download'), findsOneWidget);
    expect(find.textContaining('About 52 min'), findsOneWidget);
  });

  testWidgets('an open draft offers Surfaced', (tester) async {
    final calls = await pump(tester, open);

    expect(find.text('In the water'), findsOneWidget);
    await tester.tap(find.text('Surfaced'));
    expect(calls, ['surfaced']);
  });

  testWidgets('an open draft cannot be marked complete before it surfaces', (
    tester,
  ) async {
    await pump(tester, open);

    expect(find.text('Mark as complete'), findsNothing);
  });

  testWidgets('a closed draft does not offer Surfaced', (tester) async {
    await pump(tester, closed);

    expect(find.text('Surfaced'), findsNothing);
  });

  testWidgets('Download now and Mark as complete call back', (tester) async {
    final calls = await pump(tester, closed);

    await tester.tap(find.text('Download now'));
    await tester.tap(find.text('Mark as complete'));
    expect(calls, ['download', 'complete']);
  });
}
