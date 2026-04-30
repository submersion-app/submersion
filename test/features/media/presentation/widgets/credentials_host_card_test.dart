// Widget tests for the Saved hosts card (Phase 3c, Task 6).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 6. Deviations from the plan code:
//
// - The plan's `_FakeCredentialsService` calls `listHosts`, `testCredentials`,
//   `deleteHost`, `updateHost`. The real Phase 3a service exposes `list`,
//   `delete`, plus a Phase 3c seam `updateDisplayName(id, displayName)`. We
//   override those methods in the fake. "Test credentials" is implemented in
//   the widget against [NetworkUrlResolver.fetch] (probing the host root)
//   rather than a service method — the plan note (line 1854) explicitly
//   blesses this alternative.
// - The plan's `NetworkCredentialHost` constructor passes `DateTime` values
//   for `addedAt`/`lastUsedAt`. The Drift dataclass uses `int` epoch millis.
//   Test rows use `int` accordingly.
// - The plan's fake `headersFor` takes `String hostname`. The real signature
//   is `headersFor(Uri uri)`. The widget never calls `headersFor` from the
//   card — only the URL resolver does — so we omit it from the fake.
// - Mocks: hand-rolled `_FakeCredentialsService` and `_StubResolver` mirror
//   the pattern in `manifest_mode_panel_test.dart` (Phase 3b Task 13).

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/credentials_host_card.dart';

class _FakeCredentialsService implements NetworkCredentialsService {
  _FakeCredentialsService(this.hosts);
  final List<NetworkCredentialHost> hosts;
  final List<String> deletedIds = <String>[];
  final List<MapEntry<String, String?>> displayNameUpdates =
      <MapEntry<String, String?>>[];

  @override
  Future<List<NetworkCredentialHost>> list() async => hosts;

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    hosts.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> updateDisplayName(String id, String? displayName) async {
    displayNameUpdates.add(MapEntry(id, displayName));
    final i = hosts.indexWhere((h) => h.id == id);
    if (i >= 0) {
      hosts[i] = hosts[i].copyWith(displayName: Value(displayName));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} not stubbed in _FakeCredentialsService',
  );
}

class _StubResolver implements NetworkUrlResolver {
  _StubResolver(this._result);
  final NetworkBytesResult _result;

  @override
  Future<NetworkBytesResult> fetch(
    Uri uri, {
    Map<String, String>? extraHeaders,
  }) async {
    return _result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NetworkCredentialHost _h(
  String id,
  String hostname, {
  String? displayName,
  String authType = 'basic',
  int addedAt = 1714000000000,
  int? lastUsedAt = 1714400000000,
}) => NetworkCredentialHost(
  id: id,
  hostname: hostname,
  authType: authType,
  displayName: displayName ?? 'My $hostname',
  credentialsRef: hostname,
  addedAt: addedAt,
  lastUsedAt: lastUsedAt,
);

Widget _wrap(
  Widget child, {
  required NetworkCredentialsService creds,
  NetworkUrlResolver? resolver,
}) {
  return ProviderScope(
    overrides: [
      networkCredentialsServiceProvider.overrideWithValue(creds),
      if (resolver != null)
        networkUrlResolverProvider.overrideWithValue(resolver),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('renders one ListTile per saved host', (tester) async {
    final creds = _FakeCredentialsService([
      _h('1', 'photos.example.com'),
      _h('2', 'private.example.com'),
    ]);
    await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds: creds));
    await tester.pumpAndSettle();

    expect(find.text('photos.example.com'), findsOneWidget);
    expect(find.text('private.example.com'), findsOneWidget);
  });

  testWidgets('renders empty-state ListTile when no hosts saved', (
    tester,
  ) async {
    final creds = _FakeCredentialsService([]);
    await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds: creds));
    await tester.pumpAndSettle();

    expect(find.text('No saved credentials'), findsOneWidget);
  });

  testWidgets('Delete action removes the host and refreshes the list', (
    tester,
  ) async {
    final creds = _FakeCredentialsService([_h('1', 'photos.example.com')]);
    await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds: creds));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Confirm the dialog
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(creds.deletedIds, ['1']);
    expect(find.text('photos.example.com'), findsNothing);
    expect(find.text('No saved credentials'), findsOneWidget);
  });

  testWidgets('Test credentials action shows OK snackbar on 2xx response', (
    tester,
  ) async {
    final creds = _FakeCredentialsService([_h('1', 'photos.example.com')]);
    final resolver = _StubResolver(
      NetworkBytesOk(
        bytes: Uint8List(0),
        contentType: 'text/html',
        finalUrl: 'https://photos.example.com/',
      ),
    );
    await tester.pumpWidget(
      _wrap(const CredentialsHostCard(), creds: creds, resolver: resolver),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test credentials'));
    await tester.pumpAndSettle();

    expect(find.text('Credentials OK for photos.example.com'), findsOneWidget);
  });

  testWidgets(
    'Test credentials action shows failed snackbar on Unauthenticated',
    (tester) async {
      final creds = _FakeCredentialsService([_h('1', 'photos.example.com')]);
      final resolver = _StubResolver(const NetworkBytesUnauthenticated());
      await tester.pumpWidget(
        _wrap(const CredentialsHostCard(), creds: creds, resolver: resolver),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test credentials'));
      await tester.pumpAndSettle();

      expect(
        find.text('Credentials failed for photos.example.com'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Edit action updates the displayName via service.updateDisplayName',
    (tester) async {
      final creds = _FakeCredentialsService([
        _h('1', 'photos.example.com', displayName: 'Old name'),
      ]);
      await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds: creds));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextField, 'Display name');
      expect(field, findsOneWidget);
      await tester.enterText(field, 'Renamed');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // `MapEntry` does not override `==`, so compare key/value individually.
      expect(creds.displayNameUpdates, hasLength(1));
      expect(creds.displayNameUpdates.single.key, '1');
      expect(creds.displayNameUpdates.single.value, 'Renamed');
    },
  );

  testWidgets('Subtitle shows auth type, displayName, and last-used info', (
    tester,
  ) async {
    final creds = _FakeCredentialsService([
      _h('1', 'photos.example.com', displayName: 'Family Photos'),
    ]);
    await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds: creds));
    await tester.pumpAndSettle();

    expect(find.textContaining('Auth: basic'), findsOneWidget);
    expect(find.textContaining('Family Photos'), findsOneWidget);
    expect(find.textContaining('Last used'), findsOneWidget);
  });
}
