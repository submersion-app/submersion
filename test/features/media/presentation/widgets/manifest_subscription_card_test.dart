// Widget tests for the Manifest subscriptions card (Phase 3c, Task 7).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 7. Deviations from the plan code:
//
// - The plan's `_FakeRepo` calls `listAll`, `updateSubscription(sub)`, and
//   `deleteSubscription(id)`. The real Phase 3b repository exposes
//   `listAllActive`, `setActive(id, bool)`, `deleteById(id)`, and (Phase 3c
//   seam) `updateUrlAndDisplayName(id, manifestUrl: ..., displayName: ...)`.
//   The fake mirrors that surface.
// - The plan's `_FakePoller` returns `PollResult.success(...)` from
//   `pollNow(subscriptionId)`. The real Phase 3b poller's `pollAllDue(now)`
//   returns `Future<int>`; the Phase 3c seam `pollNow(subscriptionId, now)`
//   returns `Future<bool>`. The widget renders a generic "Poll triggered"
//   confirmation snackbar so we don't need to surface added / changed /
//   removed counts (those live in the per-subscription state row, which the
//   provider re-fetches after the cycle).
// - The plan's `ManifestSubscription` constructor passes `format: 'atom'`.
//   The real domain entity uses the `ManifestFormat` enum, so we pass
//   `ManifestFormat.atom`.
// - The plan's entity is missing `createdAt` / `updatedAt` (required) — we
//   pass them as fixed UTC instants.
// - Mocks: hand-rolled fakes mirror Task 6's pattern.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_subscription_card.dart';

class _FakeRepo implements ManifestSubscriptionRepository {
  _FakeRepo(this.subs);
  final List<ManifestSubscription> subs;
  final List<MapEntry<String, bool>> setActiveCalls =
      <MapEntry<String, bool>>[];
  final List<String> deletedIds = <String>[];
  final List<({String id, String url, String? name})> editCalls =
      <({String id, String url, String? name})>[];

  @override
  Future<List<ManifestSubscription>> listAllActive() async => subs;

  @override
  Future<void> setActive(String id, bool isActive) async {
    setActiveCalls.add(MapEntry(id, isActive));
    final i = subs.indexWhere((s) => s.id == id);
    if (i >= 0) {
      subs[i] = _copyOf(subs[i], isActive: isActive);
    }
  }

  @override
  Future<void> deleteById(String id) async {
    deletedIds.add(id);
    subs.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> updateUrlAndDisplayName(
    String id, {
    required String manifestUrl,
    required String? displayName,
  }) async {
    editCalls.add((id: id, url: manifestUrl, name: displayName));
    final i = subs.indexWhere((s) => s.id == id);
    if (i >= 0) {
      subs[i] = _copyOf(
        subs[i],
        manifestUrl: manifestUrl,
        displayName: displayName,
        clearDisplayName: displayName == null,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakePoller implements SubscriptionPoller {
  final List<String> calls = <String>[];

  @override
  Future<bool> pollNow(String subscriptionId, DateTime now) async {
    calls.add(subscriptionId);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

ManifestSubscription _sub(
  String id, {
  bool isActive = true,
  String? displayName,
  String? lastError,
  ManifestFormat format = ManifestFormat.atom,
}) {
  final epoch = DateTime.utc(2026, 4, 28);
  return ManifestSubscription(
    id: id,
    manifestUrl: 'https://example.com/feed-$id',
    format: format,
    displayName: displayName ?? 'Sub $id',
    pollIntervalSeconds: 86400,
    isActive: isActive,
    credentialsHostId: null,
    createdAt: epoch,
    updatedAt: epoch,
    lastError: lastError,
  );
}

ManifestSubscription _copyOf(
  ManifestSubscription s, {
  bool? isActive,
  String? manifestUrl,
  String? displayName,
  bool clearDisplayName = false,
}) {
  return ManifestSubscription(
    id: s.id,
    manifestUrl: manifestUrl ?? s.manifestUrl,
    format: s.format,
    displayName: clearDisplayName ? null : (displayName ?? s.displayName),
    pollIntervalSeconds: s.pollIntervalSeconds,
    isActive: isActive ?? s.isActive,
    credentialsHostId: s.credentialsHostId,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
    lastPolledAt: s.lastPolledAt,
    nextPollAt: s.nextPollAt,
    lastEtag: s.lastEtag,
    lastModified: s.lastModified,
    lastError: s.lastError,
    lastErrorAt: s.lastErrorAt,
  );
}

Widget _wrap(
  Widget child, {
  required ManifestSubscriptionRepository repo,
  required SubscriptionPoller poller,
}) => ProviderScope(
  overrides: [
    manifestSubscriptionRepositoryProvider.overrideWithValue(repo),
    subscriptionPollerProvider.overrideWithValue(poller),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('renders one row per subscription', (tester) async {
    final repo = _FakeRepo([_sub('1'), _sub('2')]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sub 1'), findsOneWidget);
    expect(find.text('Sub 2'), findsOneWidget);
  });

  testWidgets('renders empty-state row when no subscriptions', (tester) async {
    final repo = _FakeRepo([]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    expect(find.text('No manifest subscriptions'), findsOneWidget);
  });

  testWidgets('Poll now triggers SubscriptionPoller.pollNow', (tester) async {
    final repo = _FakeRepo([_sub('1')]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll now'));
    await tester.pumpAndSettle();

    expect(poller.calls, ['1']);
  });

  testWidgets('Toggling isActive persists via the repository', (tester) async {
    final repo = _FakeRepo([_sub('1', isActive: true)]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(repo.setActiveCalls, hasLength(1));
    expect(repo.setActiveCalls.single.key, '1');
    expect(repo.setActiveCalls.single.value, false);
    expect(repo.subs.single.isActive, false);
  });

  testWidgets('Delete action removes the subscription after confirmation', (
    tester,
  ) async {
    final repo = _FakeRepo([_sub('1')]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, ['1']);
    expect(find.text('No manifest subscriptions'), findsOneWidget);
  });

  testWidgets('Edit action persists URL + display-name changes', (
    tester,
  ) async {
    final repo = _FakeRepo([_sub('1', displayName: 'Old name')]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final urlField = find.widgetWithText(TextField, 'Manifest URL');
    final nameField = find.widgetWithText(TextField, 'Display name');
    expect(urlField, findsOneWidget);
    expect(nameField, findsOneWidget);

    await tester.enterText(urlField, 'https://renamed.example.com/feed');
    await tester.enterText(nameField, 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.editCalls, hasLength(1));
    expect(repo.editCalls.single.id, '1');
    expect(repo.editCalls.single.url, 'https://renamed.example.com/feed');
    expect(repo.editCalls.single.name, 'Renamed');
  });

  testWidgets('Format chip renders an uppercase label', (tester) async {
    final repo = _FakeRepo([_sub('1', format: ManifestFormat.json)]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    expect(find.text('JSON'), findsOneWidget);
  });

  testWidgets('Subtitle surfaces the last error when one is recorded', (
    tester,
  ) async {
    final repo = _FakeRepo([_sub('1', lastError: 'HTTP 500: server error')]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('HTTP 500: server error'), findsOneWidget);
  });
}
