import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';

/// The "Shared with" field on a trip or site edit page (issue #2151), the
/// one place sharing is shown (#3766). 'me' owns the trip; 'son' and
/// 'daughter' are the other profiles.
void main() {
  final everyone = [
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

  /// Pumps the field and returns the choices it reports.
  Future<List<ItemSharing>> pump(
    WidgetTester tester, {
    ItemSharing value = ItemSharing.none,
    ItemSharing? original,
    bool? mayShare = true,
    List<Diver>? divers,
  }) async {
    final changes = <ItemSharing>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiversProvider.overrideWith((_) async => divers ?? everyone),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ItemSharingField(
              kind: SharedItemKind.trip,
              value: value,
              original: original ?? value,
              mayShare: mayShare,
              ownerId: 'me',
              itemName: 'Bonaire',
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  Future<void> toggleInDialog(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(name)),
    );
    await tester.pump();
  }

  testWidgets('the owner sees Not shared and a chevron', (tester) async {
    await pump(tester);
    expect(find.text('Shared with'), findsOneWidget);
    expect(find.text('Not shared'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('the summary and chevron sit beside the label (issue #3678)', (
    tester,
  ) async {
    await pump(tester);

    final labelRight = tester.getTopRight(find.text('Shared with')).dx;
    final summary = find.text('Not shared');
    expect(tester.getTopLeft(summary).dx, labelRight + 16);
    expect(
      tester.getTopLeft(find.byIcon(Icons.chevron_right)).dx,
      tester.getTopRight(summary).dx + 4,
    );
    // The summary's box hugs its text rather than spanning to the far edge.
    expect(tester.widget<Text>(summary).textAlign, isNot(TextAlign.end));
  });

  testWidgets('the summary names who it is shared with', (tester) async {
    await pump(
      tester,
      value: const ItemSharing(profileIds: {'son', 'daughter'}),
    );
    expect(find.text('Dana, Sam'), findsOneWidget);
  });

  testWidgets('a single profile sees no field', (tester) async {
    await pump(tester, divers: [everyone.first]);
    expect(find.text('Shared with'), findsNothing);
  });

  testWidgets('another profile sees it locked, naming the owner', (
    tester,
  ) async {
    final changes = await pump(tester, mayShare: false);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Only Me can change sharing'), findsOneWidget);
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(changes, isEmpty);
  });

  testWidgets('an unknown profile sees it locked, naming nobody', (
    tester,
  ) async {
    await pump(tester, mayShare: null);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.textContaining('can change sharing'), findsNothing);
  });

  testWidgets('choosing the son reports sharing with him', (tester) async {
    final changes = await pump(tester);
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    expect(find.text('Me'), findsNothing, reason: 'the owner is not offered');
    await toggleInDialog(tester, 'Sam');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(changes, [
      const ItemSharing(profileIds: {'son'}),
    ]);
  });

  testWidgets('taking the son off asks to confirm first', (tester) async {
    final changes = await pump(
      tester,
      value: const ItemSharing(profileIds: {'son'}),
    );
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    await toggleInDialog(tester, 'Sam');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Unshare this trip?'), findsOneWidget);
    expect(changes, isEmpty);
    await tester.tap(find.text('Unshare'));
    await tester.pumpAndSettle();
    expect(changes, [ItemSharing.none]);
  });

  testWidgets('cancelling the confirmation changes nothing', (tester) async {
    final changes = await pump(tester, value: ItemSharing.all);
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    await toggleInDialog(tester, 'Sam');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('a pending choice is confirmed against the saved sharing', (
    tester,
  ) async {
    // Saved as shared with the son, then taken off him in this edit: putting
    // the daughter on alone still takes it from him, so it asks.
    final changes = await pump(
      tester,
      value: ItemSharing.none,
      original: const ItemSharing(profileIds: {'son'}),
    );
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    await toggleInDialog(tester, 'Dana');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Unshare this trip?'), findsOneWidget);
    await tester.tap(find.text('Unshare'));
    await tester.pumpAndSettle();
    expect(changes, [
      const ItemSharing(profileIds: {'daughter'}),
    ]);
  });

  testWidgets('Everyone to every current profile by name asks nothing', (
    tester,
  ) async {
    final changes = await pump(tester, value: ItemSharing.all);
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    for (final name in ['Sam', 'Dana']) {
      await toggleInDialog(tester, name);
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // Nobody who sees it now loses it, so there is nothing to confirm.
    expect(find.text('Unshare this trip?'), findsNothing);
    expect(changes, [
      const ItemSharing(profileIds: {'son', 'daughter'}),
    ]);
  });
}
