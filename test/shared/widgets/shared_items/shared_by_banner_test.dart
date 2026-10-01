import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/shared_items/shared_by_banner.dart';

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
    required bool isShared,
    bool hidden = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => active),
          isHiddenProvider.overrideWith((ref, item) async => hidden),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SharedByBanner(
              kind: SharedItemKind.trip,
              itemId: 'trip',
              ownerId: ownerId,
              isShared: isShared,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the owner to another profile', (tester) async {
    await pump(tester, active: 'b', ownerId: 'a', isShared: true);
    expect(find.text('Shared by Alice'), findsOneWidget);
  });

  testWidgets('says the item is hidden from this profile (#2679)', (
    tester,
  ) async {
    await pump(tester, active: 'b', ownerId: 'a', isShared: true, hidden: true);
    expect(
      find.text('Shared by Alice · Hidden from your profile'),
      findsOneWidget,
    );
  });

  testWidgets('shows nothing to the owner', (tester) async {
    await pump(tester, active: 'a', ownerId: 'a', isShared: true);
    expect(find.textContaining('Shared by'), findsNothing);
  });

  testWidgets('shows nothing for an unshared or ownerless item', (
    tester,
  ) async {
    await pump(tester, active: 'b', ownerId: 'a', isShared: false);
    expect(find.textContaining('Shared by'), findsNothing);
    await pump(tester, active: 'b', ownerId: null, isShared: true);
    expect(find.textContaining('Shared by'), findsNothing);
  });
}
