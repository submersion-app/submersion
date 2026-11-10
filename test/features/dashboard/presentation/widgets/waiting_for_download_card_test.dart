import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dashboard/presentation/widgets/waiting_for_download_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/download_target_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The dashboard card for drafts waiting for a dive computer download (issue
/// #637).
void main() {
  Dive draft(String id, int day, {bool open = false}) => Dive(
    id: id,
    dateTime: DateTime.utc(2026, 7, day, 10),
    entryTime: DateTime.utc(2026, 7, day, 10),
    exitTime: open ? null : DateTime.utc(2026, 7, day, 10, 45),
    isDraft: true,
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<Dive> drafts,
    DiveComputer? target,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(child: WaitingForDownloadCard()),
          ),
        ),
        GoRoute(
          path: '/dive-computers',
          builder: (context, state) => const Text('PICKER'),
        ),
        GoRoute(
          path: '/dive-computers/:id/download',
          builder: (context, state) =>
              Text('DOWNLOAD ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Text('DIVE ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...await getBaseOverrides(),
          draftDivesProvider.overrideWith((ref) async => drafts),
          downloadTargetComputerProvider.overrideWith((ref) async => target),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hidden with no drafts waiting', (tester) async {
    await pump(tester, drafts: [draft('open', 17, open: true)]);

    expect(find.text('Download now'), findsNothing);
  });

  testWidgets('counts the drafts and lists the three newest', (tester) async {
    await pump(
      tester,
      drafts: [
        draft('open', 14, open: true),
        draft('d13', 13),
        draft('d12', 12),
        draft('d11', 11),
        draft('d10', 10),
      ],
    );

    expect(find.text('4 dives waiting for your dive computer'), findsOneWidget);
    for (final id in ['d13', 'd12', 'd11']) {
      expect(find.byKey(ValueKey('waiting-draft-$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('waiting-draft-d10')), findsNothing);
    expect(find.byKey(const ValueKey('waiting-draft-open')), findsNothing);
  });

  testWidgets('one draft reads in the singular', (tester) async {
    await pump(tester, drafts: [draft('d13', 13)]);

    expect(find.text('1 dive waiting for your dive computer'), findsOneWidget);
  });

  testWidgets('Download now opens the most recent computer', (tester) async {
    await pump(
      tester,
      drafts: [draft('d13', 13)],
      target: DiveComputer(
        id: 'perdix',
        name: 'Perdix',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.tap(find.text('Download now'));
    await tester.pumpAndSettle();

    expect(find.text('DOWNLOAD perdix'), findsOneWidget);
  });

  testWidgets('with no computer, Download now opens the picker', (
    tester,
  ) async {
    await pump(tester, drafts: [draft('d13', 13)]);

    await tester.tap(find.text('Download now'));
    await tester.pumpAndSettle();

    expect(find.text('PICKER'), findsOneWidget);
  });

  testWidgets('a draft opens its dive', (tester) async {
    await pump(tester, drafts: [draft('d13', 13)]);

    await tester.tap(find.byKey(const ValueKey('waiting-draft-d13')));
    await tester.pumpAndSettle();

    expect(find.text('DIVE d13'), findsOneWidget);
  });
}
