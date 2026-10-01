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
    bool profileUnreadable = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final notifier = _RecordingSiteListNotifier();
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
            (_) async =>
                profileUnreadable ? throw StateError('no profile') : active,
          ),
          profileHidesRepositoryProvider.overrideWithValue(_FakeHides()),
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
  Future<void> unhideSites(List<String> ids) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
