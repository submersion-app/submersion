import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/widgets/shared_items/item_bulk_share.dart';

import '../../../helpers/shared_items_fixture.dart';

/// Reports one owned item skipped, as a bulk share over a mixed selection
/// does.
class _SkippingShares extends FakeItemShares {
  @override
  Future<ItemShareResult> addSharing(
    SharedItemKind kind,
    List<String> ids,
    ItemSharing add, {
    required String actingDiverId,
  }) async {
    addCalls.add((ids, add));
    return ItemShareResult(itemsShared: ids.length - 1, skippedNotOwned: 1);
  }
}

/// Sharing several trips or sites at once (issue #2151): it only adds.
void main() {
  final divers = [
    for (final (id, name) in [
      ('me', 'Me'),
      ('son', 'Sam'),
      ('daughter', 'Dana'),
    ])
      Diver(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
  ];

  /// The last share's outcome, once it has finished.
  BulkActionOutcome? outcome;

  Future<void> open(
    WidgetTester tester,
    FakeItemShares shares, {
    List<String> ids = const ['t1', 't2'],
    String? body,
    bool profilesUnreadable = false,
  }) async {
    outcome = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiversProvider.overrideWith(
            (_) async => profilesUnreadable
                ? throw StateError('database unavailable')
                : divers,
          ),
          itemSharesRepositoryProvider.overrideWithValue(shares),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The lists and Settings watch the profiles, as here: a read of
            // an unwatched provider's future does not settle.
            body: Consumer(
              builder: (context, ref, _) =>
                  !ref.watch(allDiversProvider).hasValue &&
                      !ref.watch(allDiversProvider).hasError
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: () async =>
                          outcome = await shareItemsWithProfiles(
                            context,
                            ref,
                            kind: SharedItemKind.trip,
                            ids: ids,
                            activeDiverId: 'me',
                            body: body,
                          ),
                      child: const Text('open'),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds the chosen profile to the items and reports it', (
    tester,
  ) async {
    final shares = FakeItemShares();
    await open(tester, shares);
    expect(find.text('Me'), findsNothing, reason: 'the owner is not offered');
    await tester.tap(find.text('Sam'));
    // Share enables on the next frame.
    await tester.pump();
    await tester.tap(find.text('Share'));
    await _settle(tester);
    expect(outcome, BulkActionOutcome.completed);
    final (ids, added) = shares.addCalls.single;
    expect(ids, ['t1', 't2']);
    expect(added, const ItemSharing(profileIds: {'son'}));
    expect(find.text('Shared 2 items'), findsOneWidget);
  });

  testWidgets('reports the items it skipped', (tester) async {
    final shares = _SkippingShares();
    await open(tester, shares);
    await tester.tap(find.text('Everyone'));
    // Share enables on the next frame.
    await tester.pump();
    await tester.tap(find.text('Share'));
    await _settle(tester);
    expect(
      find.text('Shared 1 item, skipped 1 you do not own'),
      findsOneWidget,
    );
  });

  testWidgets('cancel changes nothing', (tester) async {
    final shares = FakeItemShares();
    await open(tester, shares);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(outcome, BulkActionOutcome.cancelled);
    expect(shares.addCalls, isEmpty);
  });

  testWidgets('Share stays disabled until someone is chosen', (tester) async {
    await open(tester, FakeItemShares());
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Share'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('shows the body it is given', (tester) async {
    await open(tester, FakeItemShares(), body: 'Choose who sees them all.');
    expect(find.text('Choose who sees them all.'), findsOneWidget);
  });

  testWidgets('a failed profile read says to try again and fails the action', (
    tester,
  ) async {
    final shares = FakeItemShares();
    await open(tester, shares, profilesUnreadable: true);
    await _settle(tester);
    expect(outcome, BulkActionOutcome.failed);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(shares.addCalls, isEmpty);
  });
}

/// Settles after the dialog closes: the share's continuation runs in a
/// microtask that no frame schedules, so pump once more for it.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
