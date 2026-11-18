import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_detail_page_unlock_harness.dart';

/// On a page that edits the site in place, the owner sees who the site is
/// shared with, under the header (issue #4527, phase 2, plan 3). With the
/// switch off the page is as it was: `site_detail_page_sharing_test.dart`
/// still pins that the owner sees no such row there.
void main() {
  final l = AppLocalizationsEn();
  final at = DateTime.utc(2026);
  final divers = [
    Diver(id: 'me', name: 'Me', createdAt: at, updatedAt: at),
    Diver(id: 'ana', name: 'Ana', createdAt: at, updatedAt: at),
  ];

  Future<void> pumpShared(WidgetTester tester, ItemSharing sharing) =>
      pumpSitePage(
        tester,
        extra: [
          allDiversProvider.overrideWith((_) async => divers),
          itemSharingProvider((
            kind: SharedItemKind.site,
            id: harnessSite.id,
          )).overrideWith((_) async => sharing),
        ],
      );

  testWidgets('the owner sees who the site is shared with', (tester) async {
    await pumpShared(tester, const ItemSharing(profileIds: {'ana'}));

    expect(find.text(l.sharedItems_sharedWith_label), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('not shown when shared with no one', (tester) async {
    await pumpShared(tester, ItemSharing.none);

    expect(find.text(l.sharedItems_sharedWith_label), findsNothing);
  });
}
