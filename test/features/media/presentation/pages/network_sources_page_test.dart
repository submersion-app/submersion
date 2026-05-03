// Widget tests for the Network Sources settings page (Phase 3c, Task 10).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 10. Deviations from the plan code:
//
// - The plan's stub fakes call `NetworkCredentialsService.listHosts()`,
//   `testCredentials(host)`, `updateHost(host)`, `deleteHost(id)`,
//   `headersFor(String hostname)`. The real Phase 3a service exposes
//   `list()`, `delete(id)`, plus the Phase 3c seam
//   `updateDisplayName(id, displayName)` and `headersFor(Uri)`. The fakes
//   below match the real surface and rely on `noSuchMethod` to throw if
//   the page were to invoke an unstubbed method.
// - The plan's stub fake calls
//   `ManifestSubscriptionRepository.listAll()`, `updateSubscription(sub)`,
//   `deleteSubscription(id)`. The real Phase 3b repository exposes
//   `listAllActive()`, `setActive(id, bool)`, `deleteById(id)`, plus the
//   Phase 3c seam `updateUrlAndDisplayName(...)`. The fake mirrors those.
// - The page composes Tasks 6-9's cards which already have their own
//   detailed widget tests. This test only verifies that the page renders
//   the four section headers (Saved hosts, Manifest subscriptions, Cache
//   management, Scan all network media) — the inner behavior is covered
//   by the per-card tests.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';
import 'package:submersion/features/media/presentation/pages/network_sources_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

class _FakeCreds implements NetworkCredentialsService {
  @override
  Future<List<NetworkCredentialHost>> list() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeSubs implements ManifestSubscriptionRepository {
  @override
  Future<List<ManifestSubscription>> listAllActive() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeDiag implements CachedNetworkImageDiagnostics {
  @override
  Future<int> cacheSize() async => 0;

  @override
  Future<void> clearCache() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeScan implements NetworkScanService {
  @override
  NetworkScanReport? get lastReport => null;

  @override
  Stream<NetworkScanProgress> scanAll() async* {
    yield NetworkScanProgress.starting(total: 0);
    yield const NetworkScanProgress(
      phase: NetworkScanPhase.finished,
      total: 0,
      done: 0,
      available: 0,
      unreachable: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  testWidgets('renders the three cards and the scan action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkCredentialsServiceProvider.overrideWithValue(_FakeCreds()),
          manifestSubscriptionRepositoryProvider.overrideWithValue(_FakeSubs()),
          cachedNetworkImageDiagnosticsProvider.overrideWithValue(_FakeDiag()),
          networkScanServiceProvider.overrideWithValue(_FakeScan()),
        ],
        child: const MaterialApp(home: NetworkSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved hosts'), findsOneWidget);
    expect(find.text('Manifest subscriptions'), findsOneWidget);
    expect(find.text('Cache management'), findsOneWidget);
    expect(find.text('Scan all network media'), findsOneWidget);
  });

  testWidgets('AppBar title is rendered', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkCredentialsServiceProvider.overrideWithValue(_FakeCreds()),
          manifestSubscriptionRepositoryProvider.overrideWithValue(_FakeSubs()),
          cachedNetworkImageDiagnosticsProvider.overrideWithValue(_FakeDiag()),
          networkScanServiceProvider.overrideWithValue(_FakeScan()),
        ],
        child: const MaterialApp(home: NetworkSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    // The plan's example code uses "Network Sources" (capitalised) in the
    // AppBar; the section headers below the AppBar use sentence case. We
    // assert the AppBar title widget separately so it doesn't collide with
    // any future card heading that happens to share the same text.
    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);
    expect(
      find.descendant(of: appBar, matching: find.text('Network Sources')),
      findsOneWidget,
    );
  });

  testWidgets('Scan action opens NetworkScanDialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkCredentialsServiceProvider.overrideWithValue(_FakeCreds()),
          manifestSubscriptionRepositoryProvider.overrideWithValue(_FakeSubs()),
          cachedNetworkImageDiagnosticsProvider.overrideWithValue(_FakeDiag()),
          networkScanServiceProvider.overrideWithValue(_FakeScan()),
        ],
        child: const MaterialApp(home: NetworkSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Scan all network media'),
    );
    await tester.pumpAndSettle();

    // The dialog title is "Scan all network media" — same text as the
    // launcher button. After tapping, two widgets with that text should
    // exist (the button still mounted under the barrier, and the dialog
    // title), confirming the dialog actually opened.
    expect(find.text('Scan all network media'), findsNWidgets(2));
    // The dialog renders a "Done" button after the scan finishes (the fake
    // emits `finished` immediately).
    expect(find.text('Done'), findsOneWidget);

    // Drain any pending async work from the dialog before the test ends.
    unawaited(Future<void>.value());
  });
}
