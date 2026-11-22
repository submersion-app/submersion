import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_subscription_error_banner.dart';

import '../../../../helpers/l10n_test_helpers.dart';

ManifestSubscription _sub(
  String id, {
  String? lastError,
  bool isActive = true,
}) {
  final epoch = DateTime.utc(2026, 4, 28);
  return ManifestSubscription(
    id: id,
    manifestUrl: 'https://example.com/feed-$id',
    format: ManifestFormat.json,
    displayName: 'Album $id',
    pollIntervalSeconds: 86400,
    isActive: isActive,
    createdAt: epoch,
    updatedAt: epoch,
    lastError: lastError,
  );
}

class _FakeRepo implements ManifestSubscriptionRepository {
  _FakeRepo(this.subs, {this.fail = false});
  final List<ManifestSubscription> subs;
  final bool fail;

  @override
  Stream<void> watchSubscriptionsChanges() => const Stream.empty();

  @override
  Future<List<ManifestSubscription>> listAllActive() async {
    if (fail) throw StateError('no database');
    return subs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Future<void> _pump(
  WidgetTester tester,
  List<ManifestSubscription> subs, {
  bool fail = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        manifestSubscriptionRepositoryProvider.overrideWithValue(
          _FakeRepo(subs, fail: fail),
        ),
      ],
      child: localizedMaterialApp(
        locale: const Locale('en'),
        home: const Scaffold(body: MediaSubscriptionErrorBanner()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final banner = find.byKey(const Key('mediaSubscriptionErrorBanner'));

  testWidgets('hidden while every subscription polls fine', (tester) async {
    await _pump(tester, [_sub('1'), _sub('2')]);
    expect(banner, findsNothing);
  });

  testWidgets('names a failing subscription and its error', (tester) async {
    await _pump(tester, [
      _sub('1'),
      _sub('2', lastError: 'Album format not recognised'),
    ]);
    expect(banner, findsOneWidget);
    expect(find.textContaining('"Album 2"'), findsOneWidget);
    expect(find.textContaining('Album format not recognised'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('counts several failing subscriptions', (tester) async {
    await _pump(tester, [_sub('1', lastError: 'a'), _sub('2', lastError: 'b')]);
    expect(find.textContaining('2 photo subscriptions'), findsOneWidget);
  });

  testWidgets('an unreadable database shows no banner', (tester) async {
    await _pump(tester, [_sub('1', lastError: 'x')], fail: true);
    expect(banner, findsNothing);
  });

  test('a paused subscription is not reported', () {
    expect(
      failingSubscriptions([_sub('1', lastError: 'x', isActive: false)]),
      isEmpty,
    );
  });
}
