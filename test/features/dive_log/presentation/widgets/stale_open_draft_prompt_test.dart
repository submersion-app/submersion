import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/stale_open_draft_prompt.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A draft left open six hours (issue #637): the app asks whether the diver
/// surfaced, and when, since it never invents an exit time.
void main() {
  final entry = DateTime.utc(2026, 7, 17, 10);
  final open = Dive(
    id: 'draft',
    dateTime: entry,
    entryTime: entry,
    isDraft: true,
  );

  group('isStaleOpenDraft', () {
    test('an open draft becomes stale at six hours', () {
      expect(
        isStaleOpenDraft(
          open,
          entry.add(const Duration(hours: 5, minutes: 59)),
        ),
        isFalse,
      );
      expect(
        isStaleOpenDraft(open, entry.add(const Duration(hours: 6))),
        isTrue,
      );
    });

    test('a closed draft is never stale', () {
      final closed = open.copyWith(
        exitTime: entry.add(const Duration(minutes: 50)),
      );
      expect(
        isStaleOpenDraft(closed, entry.add(const Duration(hours: 9))),
        isFalse,
      );
    });

    test('a logged dive is never stale', () {
      final logged = Dive(id: 'logged', dateTime: entry, entryTime: entry);
      expect(
        isStaleOpenDraft(logged, entry.add(const Duration(hours: 9))),
        isFalse,
      );
    });
  });

  test('each draft is asked about once a session', () {
    final prompter = StaleOpenDraftPrompter();

    expect(prompter.shouldAsk(open), isTrue);
    expect(prompter.shouldAsk(open), isFalse);
    expect(prompter.shouldAsk(open.copyWith(id: 'other')), isTrue);
  });

  testWidgets('the prompt closes the draft at the picked time, an hour after '
      'entry by default', (tester) async {
    DateTime? surfacedAt;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await getBaseOverrides(),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaleOpenDraftPrompt(
              context,
              open,
              onSurfaced: (at) async => surfacedAt = at,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Did you surface?'), findsOneWidget);

    await tester.tap(find.text('Set surfacing time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(surfacedAt, entry.add(const Duration(hours: 1)));
  });

  testWidgets('Still in the water leaves the draft open', (tester) async {
    var called = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await getBaseOverrides(),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaleOpenDraftPrompt(
              context,
              open,
              onSurfaced: (_) async => called = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Still in the water'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Did you surface?'), findsNothing);
  });

  test('a picked time before the entry means the next day', () {
    expect(
      surfacingTimeFor(
        entry: DateTime.utc(2026, 7, 17, 23, 30),
        hour: 0,
        minute: 40,
      ),
      DateTime.utc(2026, 7, 18, 0, 40),
    );
    expect(
      surfacingTimeFor(entry: entry, hour: 11, minute: 5),
      DateTime.utc(2026, 7, 17, 11, 5),
    );
  });
}
