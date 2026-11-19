import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/shared_items_fixture.dart';

/// A shared site's page offers Delete to its owner and "Remove from my
/// profile" to everyone else (issue #2594).
void main() {
  const site = DiveSite(
    id: 'pier',
    name: 'Salt Pier',
    diverId: 'd1',
    isShared: true,
  );
  final divers = [
    for (final (id, name) in [('d1', 'Alice'), ('d2', 'Bob')])
      Diver(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
  ];

  Future<(_RecordingSiteListNotifier, List<String>)> pump(
    WidgetTester tester, {
    required String active,
    bool failHides = false,
    GatedActiveProfile? activeProfile,
    bool profileUnreadable = false,
    bool hidden = false,
    ItemSharing sharing = ItemSharing.all,
    DiveSite shown = site,
    bool refuseDelete = false,
    List<Override> extra = const [],
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final notifier = _RecordingSiteListNotifier()
      ..failHides = failHides
      ..refuseDelete = refuseDelete;
    final closed = <String>[];
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((ref) async => shown),
          siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith(
            (_) =>
                activeProfile?.read() ??
                (profileUnreadable
                    ? Future<String?>.error(StateError('no profile'))
                    : Future.value(active)),
          ),
          profileHidesRepositoryProvider.overrideWithValue(
            _FakeHides(hidden: hidden),
          ),
          itemSharesRepositoryProvider.overrideWithValue(
            FakeItemShares({site.id: sharing}),
          ),
          siteListNotifierProvider.overrideWith((ref) => notifier),
          ...extra,
        ].cast<Override>(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Embedded, as in the master-detail pane, whose Scaffold hosts
          // the snackbars.
          home: Scaffold(
            body: SiteDetailPage(
              siteId: site.id,
              embedded: true,
              onDeleted: () => closed.add('closed'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (notifier, closed);
  }

  /// Unlocks the page, as the record actions wait for the lock (issue
  /// #4527, phase 2), and opens its menu.
  Future<void> openUnlockedMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
  }

  // Read as "no profile", the page offered another profile's site its
  // Delete (issue #2682).
  testWidgets('an unreadable profile offers neither Delete nor Remove', (
    tester,
  ) async {
    await pump(tester, active: 'd2', profileUnreadable: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Remove from my profile'), findsNothing);
  });

  testWidgets('another profile sees Shared by and removes it from itself', (
    tester,
  ) async {
    final (notifier, closed) = await pump(tester, active: 'd2');
    expect(find.text('Shared by Alice'), findsOneWidget);

    await openUnlockedMenu(tester);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Remove from my profile'));
    await tester.pumpAndSettle();

    expect(find.text("Remove 'Salt Pier' from your profile?"), findsOneWidget);
    expect(find.textContaining('2 of your dives stay linked'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(notifier.hidden, ['pier']);
    expect(notifier.deleted, isEmpty);
    expect(closed, ['closed']);
    expect(find.text('Removed from your profile'), findsOneWidget);

    // Undo brings it back (the form's case, plan 7).
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(notifier.unhidden, ['pier']);
  });

  testWidgets('a failed remove stays on the page and says to try again', (
    tester,
  ) async {
    final (_, closed) = await pump(tester, active: 'd2', failHides: true);
    await openUnlockedMenu(tester);
    await tester.tap(find.text('Remove from my profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(closed, isEmpty);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Removed from your profile'), findsNothing);
    expect(find.text('Shared by Alice'), findsOneWidget);
  });

  testWidgets('a failed Undo says to try again', (tester) async {
    final (notifier, _) = await pump(tester, active: 'd2');
    await openUnlockedMenu(tester);
    await tester.tap(find.text('Remove from my profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    notifier.failHides = true;
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('while a profile switch re-reads the profile, the menu offers '
      'neither Delete nor Remove (issue #2677 review)', (tester) async {
    final activeProfile = GatedActiveProfile.settled('d1');
    await pump(tester, active: 'd1', activeProfile: activeProfile);
    ProviderScope.containerOf(
      tester.element(find.byType(SiteDetailPage)),
    ).invalidate(validatedCurrentDiverIdProvider);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Remove from my profile'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    activeProfile.settle('d2');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Remove from my profile'), findsOneWidget);
  });

  testWidgets('a site already hidden here offers Unhide, not Remove (#2679)', (
    tester,
  ) async {
    final (notifier, closed) = await pump(tester, active: 'd2', hidden: true);
    expect(
      find.text('Shared by Alice · Hidden from your profile'),
      findsOneWidget,
    );

    await openUnlockedMenu(tester);
    expect(find.text('Remove from my profile'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Show in my profile'));
    await tester.pumpAndSettle();

    expect(notifier.unhidden, ['pier']);
    expect(notifier.hidden, isEmpty);
    expect(closed, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the owner deletes it, warned about other profiles\' dives', (
    tester,
  ) async {
    await pump(tester, active: 'd1');
    expect(find.textContaining('Shared by'), findsNothing);

    await openUnlockedMenu(tester);
    expect(find.text('Remove from my profile'), findsNothing);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete shared site?'), findsOneWidget);
    expect(
      find.textContaining('5 dives in other profiles will lose this site.'),
      findsOneWidget,
    );
  });

  testWidgets('a profile the site no longer reaches is not offered Remove '
      '(issue #2151)', (tester) async {
    // Opened by id from one of this profile's dives after its owner took
    // the site away from it: there is nothing to remove it from.
    await pump(
      tester,
      active: 'd2',
      sharing: const ItemSharing(profileIds: {'d3'}),
    );
    expect(find.textContaining('Shared by'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove from my profile'), findsNothing);
  });

  testWidgets('a profile the site is shared with by name is offered Remove', (
    tester,
  ) async {
    await pump(
      tester,
      active: 'd2',
      sharing: const ItemSharing(profileIds: {'d2'}),
    );
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove from my profile'), findsOneWidget);
  });

  // The form's delete and Remove cases, on the page (plan 7).
  Future<void> confirmDelete(WidgetTester tester) async {
    await openUnlockedMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('the owner\'s confirmed delete removes the site and closes the '
      'pane', (tester) async {
    final (notifier, closed) = await pump(tester, active: 'd1');

    await confirmDelete(tester);

    expect(notifier.deleted, ['pier']);
    expect(closed, ['closed']);
  });

  testWidgets('an owner whose site changed hands meanwhile is refused', (
    tester,
  ) async {
    final (notifier, closed) = await pump(
      tester,
      active: 'd1',
      refuseDelete: true,
    );

    await confirmDelete(tester);

    expect(notifier.deleted, isEmpty);
    expect(closed, isEmpty);
    expect(find.text('Only its owner can delete this site'), findsOneWidget);
    expect(find.byType(SiteDetailPage), findsOneWidget);
  });

  testWidgets('a site shared by name only warns on delete as a shared site', (
    tester,
  ) async {
    await pump(
      tester,
      active: 'd1',
      shown: site.copyWith(isShared: false),
      sharing: const ItemSharing(profileIds: {'d2'}),
    );

    await openUnlockedMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete shared site?'), findsOneWidget);
  });

  testWidgets('a library site offers no Remove to a profile outside the '
      'library', (tester) async {
    await pump(
      tester,
      active: 'd2',
      shown: site.copyWith(sharedLibraryId: 'L'),
      // The list pane's width: its row also holds the library's buttons.
      size: const Size(700, 844),
      extra: [
        libraryRoleProvider(
          'L',
        ).overrideWith((ref) async => SharedLibraryRole.reader),
        libraryConnectedHereProvider('L').overrideWith((ref) async => true),
        siteLibraryStateProvider('pier').overrideWith((ref) async => null),
        libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
        currentMembershipProvider('L').overrideWith((ref) async => null),
      ],
    );

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    expect(find.text('Remove from my profile'), findsNothing);
  });
}

class _FakeHides extends Fake implements ProfileHidesRepository {
  _FakeHides({this.hidden = false});

  /// Whether the active profile has already hidden the item.
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
  ) async => (mine: 2, others: 5);
}

class _RecordingSiteListNotifier
    extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _RecordingSiteListNotifier() : super(const AsyncValue.data([]));

  final hidden = <String>[];
  final deleted = <String>[];
  final unhidden = <String>[];

  /// A hide or unhide throws, as a database error does (issue #2677).
  bool failHides = false;

  @override
  Future<int> hideSites(List<String> ids) async {
    if (failHides) throw StateError('database unavailable');
    hidden.addAll(ids);
    return ids.length;
  }

  /// A delete the repository refuses (the site changed hands meanwhile).
  bool refuseDelete = false;

  @override
  Future<bool> deleteSite(String id) async {
    if (refuseDelete) return false;
    deleted.add(id);
    return true;
  }

  @override
  Future<void> unhideSites(List<String> ids) async {
    if (failHides) throw StateError('database unavailable');
    unhidden.addAll(ids);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
