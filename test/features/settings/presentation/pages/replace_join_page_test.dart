import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/replace_and_join_service.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/pages/replace_join_page.dart';
import 'package:submersion/features/settings/presentation/providers/replace_and_join_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeService implements ReplaceAndJoinService {
  _FakeService(this.answer);

  final Future<ReplaceJoinResult> Function() answer;
  String? note;

  @override
  Future<ReplaceJoinResult> run({required String backupNote}) {
    note = backupNote;
    return answer();
  }
}

/// The full-screen replace (issue #3482, spec 6.4.1 step 6).
void main() {
  late _FakeService service;
  late ReplaceJoinEnd? end;
  late int restarts;
  late List<String> order;

  Future<void> pump(
    WidgetTester tester,
    Future<ReplaceJoinResult> Function() answer,
  ) async {
    service = _FakeService(answer);
    end = null;
    restarts = 0;
    order = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [replaceAndJoinServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => end = await ReplaceJoinPage.show(
                  context,
                  diveCount: 12,
                  backupNote: 'Before joining the library, 24 Oct 2026',
                  restart: () => restarts++,
                  onReplaced: () async => order.add('replaced'),
                ),
                child: const Text('replace'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('replace'));
    // Through the push transition; the spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('runs the replace with the note, then says so and reloads', (
    tester,
  ) async {
    final done = Completer<ReplaceJoinResult>();
    await pump(tester, () => done.future);

    expect(
      find.text('Setting the dives here aside and downloading the library...'),
      findsOneWidget,
    );
    expect(service.note, 'Before joining the library, 24 Oct 2026');

    expect(order, isEmpty);
    done.complete(const ReplaceJoinResult(ReplaceJoinOutcome.replaced));
    await tester.pumpAndSettle();
    expect(order, ['replaced']);

    expect(
      find.text(
        'Your 12 dives were set aside and the library was downloaded. '
        'Submersion will reload.',
      ),
      findsOneWidget,
    );
    // Nothing behind it is left to go back to.
    expect(find.text('replace'), findsNothing);

    await tester.tap(find.text('Continue'));
    expect(restarts, 1);
  });

  testWidgets('a refusal goes back with its reason', (tester) async {
    await pump(
      tester,
      () async => const ReplaceJoinResult(ReplaceJoinOutcome.photosBusy),
    );
    await tester.pumpAndSettle();

    expect(find.text('replace'), findsOneWidget);
    expect(end, isA<ReplaceJoinRefused>());
    expect(order, isEmpty);
    expect(
      (end! as ReplaceJoinRefused).result.outcome,
      ReplaceJoinOutcome.photosBusy,
    );
  });

  testWidgets('a failure goes back saying nothing changed', (tester) async {
    await pump(tester, () async => throw StateError('network'));
    await tester.pumpAndSettle();

    expect(find.text('replace'), findsOneWidget);
    expect(end, isA<ReplaceJoinFailed>());
  });
}
