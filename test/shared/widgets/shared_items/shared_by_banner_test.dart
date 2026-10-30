import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/shared_items/shared_by_banner.dart';

import '../../../helpers/shared_items_fixture.dart';

/// "Shared by {owner}" on another profile's shared item (issue #2594).
void main() {
  final divers = [
    for (final (id, name) in [('a', 'Alice'), ('b', 'Bob')])
      Diver(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required String active,
    required String? ownerId,
    required ItemSharing sharing,
    GatedActiveProfile? activeProfile,
    bool hidden = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith(
            (_) => activeProfile?.read() ?? Future.value(active),
          ),
          isHiddenProvider.overrideWith((ref, item) async => hidden),
          itemSharingProvider.overrideWith((ref, item) async => sharing),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SharedByBanner(
              kind: SharedItemKind.trip,
              itemId: 'trip',
              ownerId: ownerId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the owner to another profile', (tester) async {
    await pump(tester, active: 'b', ownerId: 'a', sharing: ItemSharing.all);
    expect(find.text('Shared by Alice'), findsOneWidget);
  });

  testWidgets('says nothing while a profile switch re-reads the profile '
      '(issue #2677 review)', (tester) async {
    final activeProfile = GatedActiveProfile.settled('b');
    await pump(
      tester,
      active: 'b',
      ownerId: 'a',
      sharing: ItemSharing.all,
      activeProfile: activeProfile,
    );
    expect(find.text('Shared by Alice'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(SharedByBanner)),
    ).invalidate(validatedCurrentDiverIdProvider);
    await tester.pump();
    expect(find.textContaining('Shared by'), findsNothing);

    activeProfile.settle('a');
    await tester.pumpAndSettle();
    expect(find.textContaining('Shared by'), findsNothing);
  });

  testWidgets('says the item is hidden from this profile (#2679)', (
    tester,
  ) async {
    await pump(
      tester,
      active: 'b',
      ownerId: 'a',
      sharing: ItemSharing.all,
      hidden: true,
    );
    expect(
      find.text('Shared by Alice · Hidden from your profile'),
      findsOneWidget,
    );
  });

  testWidgets('shows nothing to the owner', (tester) async {
    await pump(tester, active: 'a', ownerId: 'a', sharing: ItemSharing.all);
    expect(find.textContaining('Shared by'), findsNothing);
  });

  testWidgets('shows nothing for an unshared or ownerless item', (
    tester,
  ) async {
    await pump(tester, active: 'b', ownerId: 'a', sharing: ItemSharing.none);
    expect(find.textContaining('Shared by'), findsNothing);
    await pump(tester, active: 'b', ownerId: null, sharing: ItemSharing.all);
    expect(find.textContaining('Shared by'), findsNothing);
  });

  testWidgets('names the owner to a profile it is shared with alone', (
    tester,
  ) async {
    await pump(
      tester,
      active: 'b',
      ownerId: 'a',
      sharing: const ItemSharing(profileIds: {'b'}),
    );
    expect(find.text('Shared by Alice'), findsOneWidget);
  });

  testWidgets('renders nothing for a profile the item is no longer shared '
      'with', (tester) async {
    await pump(
      tester,
      active: 'b',
      ownerId: 'a',
      sharing: const ItemSharing(profileIds: {'c'}),
    );
    expect(find.textContaining('Shared by'), findsNothing);
  });
}
