import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/shared_items_fixture.dart';
import 'site_detail_page_unlock_harness.dart';

/// Delete, remove from profile, unhide and the library actions act on the
/// whole site at once (issue #4527, phase 2): on a page that offers
/// editing they run only while the site is unlocked with nothing to save,
/// and the sitting then starts again from the site as stored.
void main() {
  final l = AppLocalizationsEn();

  Diver diver(String id) => Diver(
    id: id,
    name: id,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  /// The page with a recording site list and the sharing reads it needs.
  Future<(SiteUnlockHarness, _RecordingSites)> pump(
    WidgetTester tester, {
    DiveSite site = harnessSite,
    bool unlockEditing = true,
    bool hidden = false,
    List<String> divers = const ['me'],
    List<Override> extra = const [],
  }) async {
    final sites = _RecordingSites();
    final page = await pumpSitePage(
      tester,
      site: site,
      unlockEditing: unlockEditing,
      initialLocation: '/root-site',
      extra: [
        siteListNotifierProvider.overrideWith((ref) => sites),
        allDiversProvider.overrideWith(
          (_) async => [for (final id in divers) diver(id)],
        ),
        profileHidesRepositoryProvider.overrideWithValue(
          _FakeHides(hidden: hidden),
        ),
        itemSharesRepositoryProvider.overrideWithValue(
          FakeItemShares({site.id: ItemSharing.all}),
        ),
        ...extra,
      ],
    );
    return (page, sites);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  PopupMenuItem<String> menuItem(WidgetTester tester, String value) =>
      tester.widget<PopupMenuItem<String>>(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == value,
        ),
      );

  testWidgets('locked, the record actions are disabled under "Unlock to use '
      'these"', (tester) async {
    final (_, sites) = await pump(tester);
    await openMenu(tester);

    expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
    expect(menuItem(tester, 'delete').enabled, isFalse);
    await tester.tap(find.text(l.diveSites_detail_deleteMenu_label));
    await tester.pumpAndSettle();
    expect(find.text(l.diveSites_detail_deleteDialog_title), findsNothing);
    expect(sites.deleted, isEmpty);
  });

  testWidgets('unlocked with unsaved changes, they wait for Save or Cancel', (
    tester,
  ) async {
    final (_, sites) = await pump(tester);
    await unlock(tester);
    await tester.ensureVisible(find.text(l.diveSites_detail_section_notes));
    await tester.tap(find.text(l.diveSites_detail_section_notes));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Choppy');
    await tester.pumpAndSettle();
    await openMenu(tester);

    // The unlocked bar keeps the menu, as a dive's does.
    expect(find.text(l.recordEdit_saveOrCancelFirst), findsOneWidget);
    expect(menuItem(tester, 'delete').enabled, isFalse);
    expect(sites.deleted, isEmpty);
  });

  testWidgets('unlocked with nothing to save, Delete asks, deletes and '
      'leaves', (tester) async {
    final (_, sites) = await pump(tester);
    await unlock(tester);
    await openMenu(tester);
    expect(find.text(l.recordEdit_unlockToUseThese), findsNothing);

    await tester.tap(find.text(l.diveSites_detail_deleteMenu_label));
    await tester.pumpAndSettle();
    expect(find.text(l.diveSites_detail_deleteDialog_title), findsOneWidget);
    await tester.tap(find.text(l.diveSites_detail_deleteDialog_confirm));
    await tester.pumpAndSettle();

    expect(sites.deleted, ['s1']);
    expect(find.text('sites pane'), findsOneWidget);
  });

  // An operation that wrote nothing (its confirmation dismissed) leaves the
  // sitting as it was: the card the diver had open stays open.
  testWidgets('a cancelled Delete keeps the open card open', (tester) async {
    final (_, sites) = await pump(tester);
    await unlock(tester);
    await tester.ensureVisible(find.text(l.diveSites_detail_section_notes));
    await tester.tap(find.text(l.diveSites_detail_section_notes));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsWidgets);

    await openMenu(tester);
    await tester.tap(find.text(l.diveSites_detail_deleteMenu_label));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.diveSites_detail_deleteDialog_cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(sites.deleted, isEmpty);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('Unhide while unlocked keeps the page unlocked', (tester) async {
    final (_, sites) = await pump(
      tester,
      site: harnessSite.copyWith(diverId: 'other'),
      divers: const ['me', 'other'],
      hidden: true,
    );
    await unlock(tester);
    await openMenu(tester);

    await tester.tap(find.text(l.sharedItems_unhideAction));
    await tester.pumpAndSettle();

    expect(sites.unhidden, ['s1']);
    // The sitting starts again from the site as stored.
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  // A failed unhide wrote nothing: the sitting stays as it was, the card
  // the diver had open still open.
  testWidgets('a failed Unhide keeps the open card open', (tester) async {
    final (_, sites) = await pump(
      tester,
      site: harnessSite.copyWith(diverId: 'other'),
      divers: const ['me', 'other'],
      hidden: true,
    );
    sites.failUnhide = true;
    await unlock(tester);
    await tester.ensureVisible(find.text(l.diveSites_detail_section_notes));
    await tester.tap(find.text(l.diveSites_detail_section_notes));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsWidgets);

    await openMenu(tester);
    await tester.tap(find.text(l.sharedItems_unhideAction));
    await tester.pumpAndSettle();

    expect(sites.unhidden, isEmpty);
    expect(find.text(l.common_error_tryAgain), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('the full page menu offers Delete to the owner', (tester) async {
    await pump(tester);
    await openMenu(tester);

    expect(find.text(l.diveSites_detail_deleteMenu_label), findsOneWidget);
  });

  testWidgets('a library reader still removes the site from the profile', (
    tester,
  ) async {
    final (_, sites) = await pump(
      tester,
      site: harnessSite.copyWith(diverId: 'other', sharedLibraryId: 'L'),
      divers: const ['me', 'other'],
      extra: [
        libraryRoleProvider(
          'L',
        ).overrideWith((ref) async => SharedLibraryRole.reader),
        libraryConnectedHereProvider('L').overrideWith((ref) async => true),
        siteLibraryStateProvider('s1').overrideWith((ref) async => null),
        libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
        currentMembershipProvider('L').overrideWith(
          (ref) async => const SharedLibraryMembership(
            id: 'm1',
            diverId: 'me',
            libraryId: 'L',
            memberId: 'mem1',
            displayName: 'Me',
            libraryName: 'Club',
            backendKind: 'folder',
          ),
        ),
      ],
    );
    // The page offers a reader no lock, so its record actions act as today.
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await openMenu(tester);

    expect(find.text(l.recordEdit_unlockToUseThese), findsNothing);
    expect(menuItem(tester, 'remove').enabled, isTrue);
    expect(sites.hidden, isEmpty);
  });

  testWidgets('with the switch off the menu is as today', (tester) async {
    await pump(tester, unlockEditing: false);
    await openMenu(tester);

    // Today's full page offers no Delete: that came with the lock.
    expect(find.text(l.recordEdit_unlockToUseThese), findsNothing);
    expect(find.text(l.diveSites_detail_deleteMenu_label), findsNothing);
  });
}

class _FakeHides extends Fake implements ProfileHidesRepository {
  _FakeHides({this.hidden = false});

  final bool hidden;

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<bool> isHidden(SharedItemKind kind, String id, String diverId) async =>
      hidden;

  @override
  Future<({int mine, int others})> diveLinkCounts(
    SharedItemKind kind,
    String id,
    String? diverId,
  ) async => (mine: 0, others: 0);
}

class _RecordingSites extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _RecordingSites() : super(const AsyncValue.data([]));

  final hidden = <String>[];
  final deleted = <String>[];
  final unhidden = <String>[];
  bool failUnhide = false;

  @override
  Future<int> hideSites(List<String> ids) async {
    hidden.addAll(ids);
    return ids.length;
  }

  @override
  Future<bool> deleteSite(String id) async {
    deleted.add(id);
    return true;
  }

  @override
  Future<void> unhideSites(List<String> ids) async {
    if (failUnhide) throw StateError('unhide failed');
    unhidden.addAll(ids);
  }

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
