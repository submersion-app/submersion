import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/hlc.dart';

void main() {
  test('round-trips fields, clocks, deleted and unknown keys', () {
    final json = {
      'id': 's1',
      'formatVersion': 1,
      'deleted': false,
      'fields': {
        'name': 'Blue Hole',
        'siteTypes': ['Reef'],
        'future': 1,
      },
      'clocks': {
        'name': {'hlc': const Hlc(5, 0, 'm1').toString(), 'memberId': 'm1'},
      },
      'somethingNew': {'a': 1},
    };
    final doc = SiteDocument.fromJson(json);
    expect(doc.id, 's1');
    expect(doc.fields['name'], 'Blue Hole');
    expect(
      doc.clocks['name'],
      const FieldClock(hlc: Hlc(5, 0, 'm1'), memberId: 'm1'),
    );
    final back = doc.toJson();
    expect(back['somethingNew'], {'a': 1});
    expect((back['fields'] as Map)['future'], 1);
    expect(SiteDocument.decode(SiteDocument.encode(doc)).toJson(), back);
  });

  test('missing clocks and deleted parse as empty and false', () {
    final doc = SiteDocument.fromJson({'id': 'x', 'fields': {}});
    expect(doc.clocks, isEmpty);
    expect(doc.deleted, isFalse);
  });

  test('an unreadable clock is dropped, not fatal', () {
    final doc = SiteDocument.fromJson({
      'id': 'x',
      'fields': {'name': 'n'},
      'clocks': {
        'name': {'hlc': 'garbage', 'memberId': 'm'},
      },
    });
    expect(doc.clocks, isEmpty);
    expect(doc.fields['name'], 'n');
  });

  test('decode rejects a document without an id', () {
    expect(
      () =>
          SiteDocument.decode(Uint8List.fromList(utf8.encode('{"fields":{}}'))),
      throwsFormatException,
    );
  });

  test('fieldNames covers every site column the spec lists', () {
    expect(SiteDocument.fieldNames, hasLength(26));
    expect(SiteDocument.fieldNames.last, 'features');
  });
}
