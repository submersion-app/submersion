import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

import '../../../helpers/mock_providers.dart';

/// The shared-item dialog pieces (issue #2594).
void main() {
  final l10n = AppLocalizationsEn();
  final divers = [
    Diver(
      id: 'a',
      name: 'Alice',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  ];

  test('sharedItemOwnerName names the owner or falls back', () {
    expect(sharedItemOwnerName(divers, 'a', l10n), 'Alice');
    expect(sharedItemOwnerName(divers, 'gone', l10n), 'another profile');
    expect(sharedItemOwnerName(divers, null, l10n), 'another profile');
  });

  // A page decides Delete or Remove from the watched profile; loading and
  // a failed read are unknown, never "no profile" (issue #2682).
  test('canDestroySharedItemOnceKnown is unknown until the profile is', () {
    bool? decide(AsyncValue<String?> active, {String? owner = 'd1'}) =>
        canDestroySharedItemOnceKnown(active, ownerId: owner);

    expect(decide(const AsyncData('d1')), isTrue);
    expect(decide(const AsyncData('d2')), isFalse);
    expect(decide(const AsyncData(null)), isTrue);
    expect(decide(const AsyncLoading()), isNull);
    expect(
      decide(AsyncError(StateError('no profile'), StackTrace.empty)),
      isNull,
    );
    // An ownerless item needs no profile.
    expect(decide(const AsyncLoading(), owner: null), isTrue);
    expect(
      decide(
        AsyncError(StateError('no profile'), StackTrace.empty),
        owner: null,
      ),
      isTrue,
    );
  });

  // A reload (a diver switch, a divers-table change) keeps the previous
  // profile's id while it runs; deciding on it would follow the profile
  // the diver just left (issue #2682 review).
  test('canDestroySharedItemOnceKnown is unknown while the profile '
      'reloads', () async {
    final reload = Completer<String?>();
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith(
          (_) => reads++ == 0 ? Future.value('d1') : reload.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(validatedCurrentDiverIdProvider, (_, _) {});
    await container.read(validatedCurrentDiverIdProvider.future);

    container.invalidate(validatedCurrentDiverIdProvider);
    final reloading = container.read(validatedCurrentDiverIdProvider);
    expect(reloading.isLoading, isTrue);
    expect(reloading.value, 'd1');
    expect(canDestroySharedItemOnceKnown(reloading, ownerId: 'd1'), isNull);

    reload.complete('d2');
    await container.read(validatedCurrentDiverIdProvider.future);
    expect(
      canDestroySharedItemOnceKnown(
        container.read(validatedCurrentDiverIdProvider),
        ownerId: 'd1',
      ),
      isFalse,
    );
  });

  test('otherProfilesDivesLine is null for none', () {
    expect(otherProfilesDivesLine(l10n, SharedItemKind.trip, 0), isNull);
    expect(
      otherProfilesDivesLine(l10n, SharedItemKind.trip, 3),
      '3 dives in other profiles will lose this trip.',
    );
    expect(
      otherProfilesDivesLine(l10n, SharedItemKind.site, 1),
      '1 dive in another profile will lose this site.',
    );
  });

  test('bulkDeleteLines states each non-empty half', () {
    expect(
      bulkDeleteLines(l10n, SharedItemKind.trip, deleteCount: 3, hideCount: 2),
      [
        '3 trips will be deleted.',
        '2 shared trips will be removed from your profile only.',
      ],
    );
    expect(
      bulkDeleteLines(l10n, SharedItemKind.site, deleteCount: 0, hideCount: 1),
      ['1 shared site will be removed from your profile only.'],
    );
    expect(
      bulkDeleteLines(
        l10n,
        SharedItemKind.trip,
        deleteCount: 2,
        hideCount: 0,
        sharedDeleteCount: 1,
      ),
      [
        '2 trips will be deleted.',
        '1 of them is shared with other profiles and will be deleted for '
            'everyone.',
      ],
    );
  });

  test('bulkDeleteLines can leave the delete count to its caller', () {
    expect(
      bulkDeleteLines(
        l10n,
        SharedItemKind.site,
        deleteCount: 2,
        hideCount: 1,
        sharedDeleteCount: 1,
        includeDeleteCount: false,
      ),
      [
        '1 of them is shared with other profiles and will be deleted for '
            'everyone.',
        '1 shared site will be removed from your profile only.',
      ],
    );
  });

  testWidgets('confirmRemoveFromProfile shows owner, own dives and hint', (
    tester,
  ) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = confirmRemoveFromProfile(
              context,
              name: 'Bonaire',
              ownerName: 'Alice',
              ownDiveCount: 2,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text("Remove 'Bonaire' from your profile?"), findsOneWidget);
    expect(find.textContaining("It stays in Alice's log"), findsOneWidget);
    expect(find.textContaining('2 of your dives stay linked'), findsOneWidget);
    expect(find.textContaining('Settings > Shared data'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('readDiveLinkCounts reads the active profile\'s split', (
    tester,
  ) async {
    late ({int mine, int others}) counts;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'b'),
          profileHidesRepositoryProvider.overrideWithValue(_Hides()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            readDiveLinkCounts(
              ref,
              SharedItemKind.trip,
              't1',
            ).then((c) => counts = c);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(counts, (mine: 2, others: 5));
  });

  testWidgets('readDiveLinkCounts falls back to none when the read fails', (
    tester,
  ) async {
    late ({int mine, int others}) counts;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith(
            (_) async => throw StateError('no profile'),
          ),
          profileHidesRepositoryProvider.overrideWithValue(_Hides()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            readDiveLinkCounts(
              ref,
              SharedItemKind.trip,
              't1',
            ).then((c) => counts = c);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(counts, (mine: 0, others: 0));
  });

  /// Reads the sharing context from a hosted list, as the trip and site
  /// lists do, and returns what it gave.
  Future<({String? activeDiverId, int diverCount})?> readFrom(
    WidgetTester tester,
    List<Override> overrides,
  ) async {
    ({String? activeDiverId, int diverCount})? sharing;
    var read = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => readSharingContext(ref, context).then((c) {
                  sharing = c;
                  read = true;
                }),
                child: const Text('read'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('read'));
    await tester.pumpAndSettle();
    expect(read, isTrue);
    return sharing;
  }

  testWidgets('readSharingContext reads the profile and the profile count', (
    tester,
  ) async {
    final sharing = await readFrom(tester, [
      validatedCurrentDiverIdProvider.overrideWith((_) async => 'a'),
      allDiversProvider.overrideWith((_) async => divers),
    ]);
    expect(sharing, (activeDiverId: 'a', diverCount: 1));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('readSharingContext keeps a missing profile, which is no '
      'failure', (tester) async {
    final sharing = await readFrom(tester, [
      validatedCurrentDiverIdProvider.overrideWith((_) async => null),
      allDiversProvider.overrideWith((_) async => const []),
    ]);
    expect(sharing, (activeDiverId: null, diverCount: 0));
    expect(find.byType(SnackBar), findsNothing);
  });

  // A failed read must not pass for "no profile": the split would then
  // offer to delete every selected item, another profile's shared ones
  // too, and the delete would throw on its own read (issue #2682).
  testWidgets('readSharingContext gives nothing and says so when the '
      'profile cannot be read', (tester) async {
    final sharing = await readFrom(tester, [
      validatedCurrentDiverIdProvider.overrideWith(
        (_) async => throw StateError('no profile'),
      ),
      allDiversProvider.overrideWith((_) async => divers),
    ]);
    expect(sharing, isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  // Without the count the owner's dialog would drop the "deleted for
  // everyone" line, so this fails closed too (issue #2682).
  testWidgets('readSharingContext gives nothing and says so when the '
      'profiles cannot be counted', (tester) async {
    final sharing = await readFrom(tester, [
      validatedCurrentDiverIdProvider.overrideWith((_) async => 'a'),
      allDiversProvider.overrideWith(
        (_) async => throw StateError('no divers'),
      ),
    ]);
    expect(sharing, isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  group('a hide or unhide that fails (issue #2677)', () {
    const tryAgain = 'Something went wrong. Please try again.';

    /// Pumps a page whose button runs [run] with the page's messenger and
    /// localizations, as a caller does, and returns the result holder.
    Future<List<Object?>> pumpRunner(
      WidgetTester tester,
      Future<Object?> Function(ScaffoldMessengerState, AppLocalizations) run,
    ) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await run(ScaffoldMessenger.of(context), context.l10n),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('runHideChange gives the result and says nothing', (
      tester,
    ) async {
      final results = await pumpRunner(
        tester,
        (messenger, l10n) => runHideChange(messenger, l10n, () async => 3),
      );
      expect(results, [3]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('runHideChange says to try again and gives null', (
      tester,
    ) async {
      final results = await pumpRunner(
        tester,
        (messenger, l10n) => runHideChange<int>(
          messenger,
          l10n,
          () async => throw StateError('database unavailable'),
        ),
      );
      expect(results, [null]);
      expect(find.text(tryAgain), findsOneWidget);
    });

    test('tryHideChange gives the result, or null for a failure', () async {
      expect(await tryHideChange(() async => true), isTrue);
      expect(
        await tryHideChange<bool>(
          () async => throw StateError('database unavailable'),
        ),
        isNull,
      );
    });
  });
}

class _Hides extends Fake implements ProfileHidesRepository {
  @override
  Future<({int mine, int others})> diveLinkCounts(
    SharedItemKind kind,
    String id,
    String? diverId,
  ) async => diverId == 'b' ? (mine: 2, others: 5) : (mine: 0, others: 0);
}
