// Widget tests for the Manifest subscriptions card (Phase 3c, Task 7).
//
// Adapted from plan
// `docs/design/plans/2026-04-28-media-source-extension-phase3c.md`
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
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';
import 'package:submersion/features/media/data/synology/synology_album_source.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_subscription_card.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _FakeRepo implements ManifestSubscriptionRepository {
  _FakeRepo(this.subs);
  final List<ManifestSubscription> subs;
  final List<MapEntry<String, bool>> setActiveCalls =
      <MapEntry<String, bool>>[];
  final List<String> deletedIds = <String>[];
  final List<({String id, String url, String? name})> editCalls =
      <({String id, String url, String? name})>[];

  /// No database, so nothing ever ticks. Without this the class falls through
  /// to noSuchMethod, which returns null where a Stream is required.
  @override
  Stream<void> watchSubscriptionsChanges() => const Stream.empty();

  @override
  Future<List<ManifestSubscription>> listAllActive() async => subs;

  /// The error each subscription's last poll recorded, by id.
  final Map<String, String?> errors = {};

  final List<({String id, int seconds})> intervalCalls = [];

  @override
  Future<void> setPollInterval(String id, int pollIntervalSeconds) async {
    intervalCalls.add((id: id, seconds: pollIntervalSeconds));
  }

  @override
  Future<ManifestSubscription?> getById(String id) async {
    final i = subs.indexWhere((s) => s.id == id);
    if (i < 0) return null;
    return _copyOf(subs[i], lastError: errors[id], setLastError: true);
  }

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

/// Records each poll and leaves [errors] in turn as the poll's recorded
/// error, the way the real poller writes it to the subscription's state.
class _ScriptedPoller implements SubscriptionPoller {
  _ScriptedPoller(this.repo, this.errors);
  final _FakeRepo repo;
  final List<String?> errors;
  final List<String> calls = <String>[];

  @override
  Future<bool> pollNow(String subscriptionId, DateTime now) async {
    final error = calls.length < errors.length ? errors[calls.length] : null;
    calls.add(subscriptionId);
    repo.errors[subscriptionId] = error;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeCredentials implements NetworkCredentialsService {
  final List<({String hostname, String authType, String? password})> saves = [];

  @override
  Future<void> save({
    required String hostname,
    required String authType,
    String? username,
    String? password,
    String? token,
    String? displayName,
  }) async {
    saves.add((hostname: hostname, authType: authType, password: password));
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
  String? manifestUrl,
  ManifestFormat format = ManifestFormat.atom,
}) {
  final epoch = DateTime.utc(2026, 4, 28);
  return ManifestSubscription(
    id: id,
    manifestUrl: manifestUrl ?? 'https://example.com/feed-$id',
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
  String? lastError,
  bool setLastError = false,
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
    lastError: setLastError ? lastError : s.lastError,
    lastErrorAt: s.lastErrorAt,
  );
}

Widget _wrap(
  Widget child, {
  required ManifestSubscriptionRepository repo,
  required SubscriptionPoller poller,
  NetworkCredentialsService? credentials,
}) => ProviderScope(
  overrides: [
    manifestSubscriptionRepositoryProvider.overrideWithValue(repo),
    subscriptionPollerProvider.overrideWithValue(poller),
    if (credentials != null)
      networkCredentialsServiceProvider.overrideWithValue(credentials),
  ],
  child: localizedMaterialApp(
    locale: const Locale('en'),
    home: Scaffold(body: child),
  ),
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

  group('Poll now on a Synology Photos share', () {
    const shareUrl = 'https://nas.example.com:5001/mo/sharing/code1';
    final field = find.byKey(const Key('synologyPasswordDialogField'));
    final save = find.byKey(const Key('synologyPasswordDialogSave'));

    Future<void> tapPollNow(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poll now'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for a missing password, saves it, polls again', (
      tester,
    ) async {
      final repo = _FakeRepo([_sub('1', manifestUrl: shareUrl)]);
      final poller = _ScriptedPoller(repo, [kSynologyPasswordMissingMessage]);
      final creds = _FakeCredentials();
      await tester.pumpWidget(
        _wrap(
          const ManifestSubscriptionCard(),
          repo: repo,
          poller: poller,
          credentials: creds,
        ),
      );
      await tester.pumpAndSettle();
      await tapPollNow(tester);

      expect(field, findsOneWidget);
      await tester.enterText(field, 'pw');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(creds.saves, [
        (
          hostname: 'nas.example.com:5001/mo/sharing/code1',
          authType: kSynologyShareAuthType,
          password: 'pw',
        ),
      ]);
      expect(poller.calls, ['1', '1']);
      expect(field, findsNothing);
    });

    testWidgets('a refused password asks again until cancelled', (
      tester,
    ) async {
      final repo = _FakeRepo([_sub('1', manifestUrl: shareUrl)]);
      final poller = _ScriptedPoller(repo, [
        kSynologyPasswordRejectedMessage,
        kSynologyPasswordRejectedMessage,
      ]);
      final creds = _FakeCredentials();
      await tester.pumpWidget(
        _wrap(
          const ManifestSubscriptionCard(),
          repo: repo,
          poller: poller,
          credentials: creds,
        ),
      );
      await tester.pumpAndSettle();
      await tapPollNow(tester);

      expect(
        find.text('The share did not accept the password. Enter it again.'),
        findsOneWidget,
      );
      await tester.enterText(field, 'wrong');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(poller.calls, ['1', '1']);
      expect(creds.saves, hasLength(1));
      expect(field, findsNothing);
    });

    testWidgets('a poll that succeeds asks nothing', (tester) async {
      final repo = _FakeRepo([_sub('1', manifestUrl: shareUrl)]);
      final poller = _ScriptedPoller(repo, [null]);
      final creds = _FakeCredentials();
      await tester.pumpWidget(
        _wrap(
          const ManifestSubscriptionCard(),
          repo: repo,
          poller: poller,
          credentials: creds,
        ),
      );
      await tester.pumpAndSettle();
      await tapPollNow(tester);

      expect(field, findsNothing);
      expect(poller.calls, ['1']);
      expect(creds.saves, isEmpty);
    });

    testWidgets('a feed with the same error asks nothing', (tester) async {
      final repo = _FakeRepo([_sub('1')]);
      final poller = _ScriptedPoller(repo, [kSynologyPasswordMissingMessage]);
      await tester.pumpWidget(
        _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
      );
      await tester.pumpAndSettle();
      await tapPollNow(tester);

      expect(field, findsNothing);
    });
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
    // The interval was left alone, so it is not written.
    expect(repo.intervalCalls, isEmpty);
  });

  testWidgets('Edit action changes the poll interval', (tester) async {
    final repo = _FakeRepo([_sub('1')]);
    final poller = _FakePoller();
    await tester.pumpWidget(
      _wrap(const ManifestSubscriptionCard(), repo: repo, poller: poller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('24 hours'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manifestSubscriptionInterval')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hour').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.intervalCalls, [(id: '1', seconds: 3600)]);
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
