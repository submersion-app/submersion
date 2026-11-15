import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/fake_catalogue_gap_service.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

CataloguePair _pair(
  String siteId, {
  Set<CatalogueGapField> fields = const {CatalogueGapField.depth},
}) => CataloguePair(
  site: DiveSite(id: siteId, name: 'Site $siteId', catalogueId: 'r_$siteId'),
  record: CatalogueSite(id: 'r_$siteId', name: 'Site $siteId', source: 'osm'),
  kind: CataloguePairKind.linked,
  fields: fields,
);

/// Preferences whose writes land only when the test says so, the way a
/// slow platform channel would let them.
class _SlowPrefs implements SharedPreferences {
  final sent = <List<String>>[];
  final _waiting = <(Completer<bool>, List<String>)>[];
  List<String>? stored;

  @override
  List<String>? getStringList(String key) => null;

  @override
  Future<bool> setStringList(String key, List<String> value) {
    sent.add(value);
    final completer = Completer<bool>();
    _waiting.add((completer, value));
    return completer.future;
  }

  void finishNext() {
    final (completer, value) = _waiting.removeAt(0);
    stored = value;
    completer.complete(true);
  }

  void failNext() {
    final (completer, _) = _waiting.removeAt(0);
    completer.completeError(StateError('disk full'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container({
    List<CataloguePair>? pairs,
    String? diverId = 'd1',
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentDiverIdProvider.overrideWith((ref) {
          final notifier = MockCurrentDiverIdNotifier();
          if (diverId != null) notifier.setCurrentDiver(diverId);
          return notifier;
        }),
        if (pairs != null)
          catalogueGapPairsProvider.overrideWith((ref) async => pairs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the notice', () {
    test('counts the pairs that are waiting', () async {
      final c = container(pairs: [_pair('a'), _pair('b')]);
      await c.read(catalogueGapPairsProvider.future);

      expect(c.read(catalogueGapNoticeCountProvider), 2);
    });

    test('is silent while the pairs are still being found', () {
      final c = container(pairs: [_pair('a')]);

      expect(c.read(catalogueGapNoticeCountProvider), 0);
    });

    test('is silent with no pairs', () async {
      final c = container(pairs: const []);
      await c.read(catalogueGapPairsProvider.future);

      expect(c.read(catalogueGapNoticeCountProvider), 0);
    });

    test('stays away once the waiting pairs are dismissed', () async {
      final pairs = [_pair('a'), _pair('b')];
      final c = container(pairs: pairs);
      await c.read(catalogueGapPairsProvider.future);

      c.read(catalogueGapNoticeSeenProvider.notifier).dismiss([
        for (final pair in pairs) pair.key,
      ]);

      expect(c.read(catalogueGapNoticeCountProvider), 0);
    });

    test('returns, with the full count, when a new pair appears', () async {
      final first = container(pairs: [_pair('a')]);
      await first.read(catalogueGapPairsProvider.future);
      first.read(catalogueGapNoticeSeenProvider.notifier).dismiss([
        _pair('a').key,
      ]);

      final later = container(pairs: [_pair('a'), _pair('b')]);
      await later.read(catalogueGapPairsProvider.future);

      expect(later.read(catalogueGapNoticeCountProvider), 2);
    });

    test('returns when a dismissed pair has more to offer', () async {
      final first = container(pairs: [_pair('a')]);
      await first.read(catalogueGapPairsProvider.future);
      first.read(catalogueGapNoticeSeenProvider.notifier).dismiss([
        _pair('a').key,
      ]);

      final grown = _pair(
        'a',
        fields: {CatalogueGapField.depth, CatalogueGapField.description},
      );
      final later = container(pairs: [grown]);
      await later.read(catalogueGapPairsProvider.future);

      expect(later.read(catalogueGapNoticeCountProvider), 1);
    });

    test('a dismissal survives a restart', () async {
      final first = container(pairs: [_pair('a')]);
      first.read(catalogueGapNoticeSeenProvider.notifier).dismiss([
        _pair('a').key,
      ]);
      await Future<void>.delayed(Duration.zero);

      final restarted = container(pairs: [_pair('a')]);
      await restarted.read(catalogueGapPairsProvider.future);

      expect(restarted.read(catalogueGapNoticeSeenProvider), {_pair('a').key});
      expect(restarted.read(catalogueGapNoticeCountProvider), 0);
    });

    test('a dismissal replaces what was remembered before', () async {
      final c = container(pairs: [_pair('b')]);
      c.read(catalogueGapNoticeSeenProvider.notifier)
        ..dismiss([_pair('a').key])
        ..dismiss([_pair('b').key]);

      expect(c.read(catalogueGapNoticeSeenProvider), {_pair('b').key});
    });

    test('a second dismissal is written only after the first', () async {
      final slow = _SlowPrefs();
      final notifier = CatalogueGapNoticeNotifier(slow, 'd1');

      notifier.dismiss(['a']);
      notifier.dismiss(['b']);
      await Future<void>.delayed(Duration.zero);
      // The first write is still under way: the second has not been sent,
      // so it cannot finish first and be overwritten by the older value.
      expect(slow.sent, [
        ['a'],
      ]);

      slow.finishNext();
      await Future<void>.delayed(Duration.zero);
      slow.finishNext();
      await Future<void>.delayed(Duration.zero);

      expect(slow.stored, ['b']);
      expect(notifier.state, {'b'});
    });

    test('a failed write does not hold up the next', () async {
      final slow = _SlowPrefs();
      final notifier = CatalogueGapNoticeNotifier(slow, 'd1');

      notifier.dismiss(['a']);
      notifier.dismiss(['b']);
      await Future<void>.delayed(Duration.zero);
      slow.failNext();
      await Future<void>.delayed(Duration.zero);
      slow.finishNext();
      await Future<void>.delayed(Duration.zero);

      expect(slow.stored, ['b']);
    });

    test("one diver's dismissal is not another's", () async {
      final first = container(pairs: [_pair('a')]);
      first.read(catalogueGapNoticeSeenProvider.notifier).dismiss([
        _pair('a').key,
      ]);
      await Future<void>.delayed(Duration.zero);

      final other = container(pairs: [_pair('a')], diverId: 'd2');
      await other.read(catalogueGapPairsProvider.future);

      expect(other.read(catalogueGapNoticeCountProvider), 1);
    });
  });

  group('the pair of one site', () {
    test('is found by the site', () async {
      final c = container(pairs: [_pair('a'), _pair('b')]);
      await c.read(catalogueGapPairsProvider.future);

      expect(c.read(catalogueGapPairForSiteProvider('b'))!.record.id, 'r_b');
      expect(c.read(catalogueGapPairForSiteProvider('zzz')), isNull);
    });

    test('is nothing while the pairs are still being found', () {
      final c = container(pairs: [_pair('a')]);

      expect(c.read(catalogueGapPairForSiteProvider('a')), isNull);
    });
  });

  group('finding the pairs', () {
    late FakeCatalogueGapService service;

    setUp(() async {
      await setUpTestDatabase();
      service = FakeCatalogueGapService();
    });

    tearDown(tearDownTestDatabase);

    ProviderContainer live() {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
          catalogueGapServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('asks the service for the current diver', () async {
      service.pairs = [_pair('a')];
      final c = live();

      final pairs = await c.read(catalogueGapPairsProvider.future);

      expect(pairs.single.site.id, 'a');
      expect(service.asked, ['d1']);
    });

    test('asks again when a catalogue import lands', () async {
      final c = live();
      final sub = c.listen(catalogueGapPairsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(catalogueGapPairsProvider.future);
      expect(service.asked, hasLength(1));

      service.pairs = [_pair('a')];
      c.read(siteCatalogueRevisionProvider.notifier).state++;
      final pairs = await c.read(catalogueGapPairsProvider.future);

      expect(pairs, hasLength(1));
      expect(service.asked, hasLength(2));
    });

    test('a search a newer one has replaced is told to stop', () async {
      final c = live();
      final sub = c.listen(catalogueGapPairsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(catalogueGapPairsProvider.future);
      final first = service.cancelChecks.single;
      expect(first(), isFalse);

      c.read(siteCatalogueRevisionProvider.notifier).state++;
      await c.read(catalogueGapPairsProvider.future);

      expect(first(), isTrue);
      expect(service.cancelChecks.last(), isFalse);
    });

    test('asks again when a site changes', () async {
      final c = live();
      final sub = c.listen(catalogueGapPairsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(catalogueGapPairsProvider.future);

      service.pairs = [_pair('a')];
      await SiteRepository().createSite(const DiveSite(id: 's1', name: 'New'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final pairs = await c.read(catalogueGapPairsProvider.future);

      expect(pairs, hasLength(1));
    });
  });
}
