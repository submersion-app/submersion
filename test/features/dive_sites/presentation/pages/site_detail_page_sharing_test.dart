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
    bool hidden = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final notifier = _RecordingSiteListNotifier()..failHides = failHides;
    final closed = <String>[];
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteProvider(site.id).overrideWith((ref) async => site),
          siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith(
            (_) => activeProfile?.read() ?? Future.value(active),
          ),
          profileHidesRepositoryProvider.overrideWithValue(
            _FakeHides(hidden: hidden),
          ),
          siteListNotifierProvider.overrideWith((ref) => notifier),
        ],
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

  testWidgets('another profile sees Shared by and removes it from itself', (
    tester,
  ) async {
    final (notifier, closed) = await pump(tester, active: 'd2');
    expect(find.text('Shared by Alice'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
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
  });

  testWidgets('a failed remove stays on the page and says to try again', (
    tester,
  ) async {
    final (_, closed) = await pump(tester, active: 'd2', failHides: true);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Remove from my profile'), findsNothing);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete shared site?'), findsOneWidget);
    expect(
      find.textContaining('5 dives in other profiles will lose this site.'),
      findsOneWidget,
    );
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

  @override
  Future<bool> deleteSite(String id) async {
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
