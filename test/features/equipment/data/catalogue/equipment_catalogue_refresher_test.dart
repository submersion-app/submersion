import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_refresher.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';

String _file(String generatedAt, {int format = 1, bool empty = false}) =>
    jsonEncode({
      'format': format,
      'generatedAt': generatedAt,
      'records': [
        if (!empty)
          {
            'id': 'maker-thing',
            'manufacturer': 'Maker',
            'model': 'Thing',
            'equipmentType': 'computer',
            'sources': [],
          },
      ],
    });

EquipmentCatalogueFile _parsed(DateTime at) =>
    EquipmentCatalogueFile(format: 1, generatedAt: at, records: const []);

void main() {
  group('chooseEquipmentCatalogue', () {
    final older = _parsed(DateTime.utc(2026, 11, 1));
    final newer = _parsed(DateTime.utc(2026, 11, 20));

    test('the newer of the two', () {
      expect(chooseEquipmentCatalogue(older, newer), newer);
      expect(chooseEquipmentCatalogue(newer, older), newer);
    });

    test('either when the other is missing', () {
      expect(chooseEquipmentCatalogue(older, null), older);
      expect(chooseEquipmentCatalogue(null, newer), newer);
      expect(chooseEquipmentCatalogue(null, null), isNull);
    });

    test('the bundled copy when both are the same age', () {
      final same = _parsed(DateTime.utc(2026, 11, 1));
      expect(identical(chooseEquipmentCatalogue(older, same), older), isTrue);
    });
  });

  group('EquipmentCatalogueRefresher', () {
    late SharedPreferences prefs;
    late List<String> written;
    late int fetches;
    final now = DateTime.utc(2026, 11, 27, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      written = [];
      fetches = 0;
    });

    EquipmentCatalogueRefresher refresher({
      String? body,
      Object? error,
      bool enabled = true,
      bool isBrowser = false,
    }) => EquipmentCatalogueRefresher(
      fetch: () async {
        fetches++;
        if (error != null) throw error;
        return body;
      },
      writeCache: (json) async => written.add(json),
      prefs: prefs,
      enabled: () => enabled,
      isBrowser: isBrowser,
      now: () => now,
    );

    test('does nothing when the setting is off', () async {
      expect(await refresher(enabled: false).refreshIfDue(), isFalse);
      expect(fetches, 0);
    });

    test('does nothing in a browser', () async {
      expect(await refresher(isBrowser: true).refreshIfDue(), isFalse);
      expect(fetches, 0);
    });

    test('does nothing within 24 hours of the last good download', () async {
      await prefs.setInt(
        kEquipmentCatalogueFetchedAtKey,
        now.subtract(const Duration(hours: 23)).millisecondsSinceEpoch,
      );
      expect(
        await refresher(body: _file('2026-11-27T00:00:00Z')).refreshIfDue(),
        isFalse,
      );
      expect(fetches, 0);
    });

    test('downloads again after 24 hours', () async {
      await prefs.setInt(
        kEquipmentCatalogueFetchedAtKey,
        now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
      );
      expect(
        await refresher(body: _file('2026-11-27T00:00:00Z')).refreshIfDue(),
        isTrue,
      );
    });

    test('writes the cache and the time on success', () async {
      final body = _file('2026-11-27T00:00:00Z');
      expect(await refresher(body: body).refreshIfDue(), isTrue);
      expect(written, [body]);
      expect(
        prefs.getInt(kEquipmentCatalogueFetchedAtKey),
        now.millisecondsSinceEpoch,
      );
    });

    test('keeps the cache when the body is malformed', () async {
      expect(await refresher(body: '{nope').refreshIfDue(), isFalse);
      expect(written, isEmpty);
    });

    test('an attempt that keeps nothing still waits a day', () async {
      expect(await refresher().refreshIfDue(), isFalse);
      expect(fetches, 1);
      expect(await refresher().refreshIfDue(), isFalse);
      expect(fetches, 1);
    });

    test('keeps the cache when the format is unsupported', () async {
      final body = _file('2026-11-27T00:00:00Z', format: 2);
      expect(await refresher(body: body).refreshIfDue(), isFalse);
      expect(written, isEmpty);
    });

    test('keeps the cache when the file has no usable record', () async {
      final body = _file('2026-11-27T00:00:00Z', empty: true);
      expect(await refresher(body: body).refreshIfDue(), isFalse);
      expect(written, isEmpty);
    });

    test('keeps the cache when the file is dated in the future', () async {
      // A copy dated ahead would beat every later bundled copy.
      final body = _file('2026-12-05T00:00:00Z');
      expect(await refresher(body: body).refreshIfDue(), isFalse);
      expect(written, isEmpty);
    });

    test('a refresh asked for while one runs joins it', () async {
      final gate = Completer<void>();
      final r = EquipmentCatalogueRefresher(
        fetch: () async {
          fetches++;
          await gate.future;
          return _file('2026-11-27T00:00:00Z');
        },
        writeCache: (json) async => written.add(json),
        prefs: prefs,
        enabled: () => true,
        isBrowser: false,
        now: () => now,
      );
      final first = r.refreshIfDue();
      final second = r.refreshIfDue();
      gate.complete();
      expect(await Future.wait([first, second]), [true, true]);
      expect(fetches, 1);
      expect(written, hasLength(1));
    });

    test('keeps the cache when nothing is published', () async {
      expect(await refresher().refreshIfDue(), isFalse);
      expect(written, isEmpty);
    });

    test(
      'a failed download is swallowed and tried again a day later',
      () async {
        expect(
          await refresher(error: Exception('offline')).refreshIfDue(),
          isFalse,
        );
        expect(written, isEmpty);
        expect(
          prefs.getInt(kEquipmentCatalogueFetchedAtKey),
          now.millisecondsSinceEpoch,
        );
      },
    );
  });
}
