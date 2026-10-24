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
import 'package:submersion/shared/widgets/shared_items/item_sharing_row.dart';

/// Records what the row asks the repository to store.
class _RecordingShares extends ItemSharesRepository {
  _RecordingShares({this.refuse = false});

  /// Answers as the repository does for a profile that may not change it.
  final bool refuse;
  final calls = <ItemSharing>[];
  final actingDivers = <String?>[];

  @override
  Future<bool> setSharing(
    SharedItemKind kind,
    String id,
    ItemSharing sharing, {
    required String? actingDiverId,
  }) async {
    calls.add(sharing);
    actingDivers.add(actingDiverId);
    return !refuse;
  }
}

/// The "Shared with" row on a trip or site page (issue #2151). 'me' owns
/// the trip; 'son' and 'daughter' are the other profiles.
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

  Future<_RecordingShares> pump(
    WidgetTester tester, {
    required String active,
    ItemSharing sharing = ItemSharing.none,
    bool refuse = false,
  }) async {
    final shares = _RecordingShares(refuse: refuse);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => active),
          itemSharesRepositoryProvider.overrideWithValue(shares),
          itemSharingProvider.overrideWith((ref, item) async => sharing),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ItemSharingRow(
              kind: SharedItemKind.trip,
              itemId: 'bonaire',
              ownerId: 'me',
              itemName: 'Bonaire',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return shares;
  }

  testWidgets('the owner sees Not shared and a chevron', (tester) async {
    await pump(tester, active: 'me');
    expect(find.text('Shared with'), findsOneWidget);
    expect(find.text('Not shared'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('the owner sees who it is shared with', (tester) async {
    await pump(
      tester,
      active: 'me',
      sharing: const ItemSharing(profileIds: {'son', 'daughter'}),
    );
    expect(find.text('Dana, Sam'), findsOneWidget);
  });

  testWidgets('another profile sees nothing', (tester) async {
    await pump(tester, active: 'son', sharing: ItemSharing.all);
    expect(find.text('Shared with'), findsNothing);
  });

  testWidgets('choosing the son shares it with him', (tester) async {
    final shares = await pump(tester, active: 'me');
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    expect(find.text('Me'), findsNothing, reason: 'the owner is not offered');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sam')),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(shares.calls, [
      const ItemSharing(profileIds: {'son'}),
    ]);
  });

  testWidgets('taking the son off asks to confirm first', (tester) async {
    final shares = await pump(
      tester,
      active: 'me',
      sharing: const ItemSharing(profileIds: {'son'}),
    );
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sam')),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Unshare this trip?'), findsOneWidget);
    expect(shares.calls, isEmpty);
    await tester.tap(find.text('Unshare'));
    await tester.pumpAndSettle();
    expect(shares.calls, [ItemSharing.none]);
  });

  testWidgets('cancelling the confirmation changes nothing', (tester) async {
    final shares = await pump(tester, active: 'me', sharing: ItemSharing.all);
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sam')),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(shares.calls, isEmpty);
  });

  testWidgets('the save names the active profile, which the repository '
      'checks (issue #2151)', (tester) async {
    final shares = await pump(tester, active: 'me');
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sam')),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(shares.actingDivers, ['me']);
  });

  testWidgets('a refused save says only the owner can change it', (
    tester,
  ) async {
    await pump(tester, active: 'me', refuse: true);
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sam')),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Only Me can change sharing'), findsOneWidget);
  });

  testWidgets('Everyone to every current profile by name asks nothing', (
    tester,
  ) async {
    final shares = await pump(tester, active: 'me', sharing: ItemSharing.all);
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    for (final name in ['Sam', 'Dana']) {
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(name),
        ),
      );
      await tester.pump();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // Nobody who sees it now loses it, so there is nothing to confirm.
    expect(find.text('Unshare this trip?'), findsNothing);
    expect(shares.calls, [
      const ItemSharing(profileIds: {'son', 'daughter'}),
    ]);
  });
}
