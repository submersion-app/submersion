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
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

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

  testWidgets('readSharingContext reads the profile and the profile count', (
    tester,
  ) async {
    late ({String? activeDiverId, int diverCount}) sharing;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'a'),
          allDiversProvider.overrideWith((_) async => divers),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            readSharingContext(ref).then((c) => sharing = c);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(sharing, (activeDiverId: 'a', diverCount: 1));
  });

  testWidgets('readSharingContext falls back when the reads fail', (
    tester,
  ) async {
    late ({String? activeDiverId, int diverCount}) sharing;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith(
            (_) async => throw StateError('no profile'),
          ),
          allDiversProvider.overrideWith(
            (_) async => throw StateError('no divers'),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            readSharingContext(ref).then((c) => sharing = c);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(sharing, (activeDiverId: null, diverCount: 0));
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
