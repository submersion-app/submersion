import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
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

  testWidgets('confirmRemoveFromProfile shows owner, own dives and hint', (
    tester,
  ) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
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
}
