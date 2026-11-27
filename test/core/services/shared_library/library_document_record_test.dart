import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/hlc.dart';

FieldClock c(int t, String m) => FieldClock(hlc: Hlc(t, 0, m), memberId: m);

Map<String, Object?> page({String fileId = 'f1'}) => {
  'id': 'p1',
  'pageIndex': 0,
  'side': null,
  'fileName': 'access.pdf',
  'mimeType': 'application/pdf',
  'sizeBytes': 3,
  'fileId': fileId,
  'sha256': 'abc',
};

void main() {
  final doc = LibraryDocumentRecord(
    id: 'doc1',
    siteId: 'site1',
    fields: {
      'type': 'map',
      'title': 'Access',
      'tags': ['Parking'],
      'pages': [page()],
    },
    clocks: {'title': c(5, 'm1'), 'pages': c(6, 'm1')},
  );

  test('round trip keeps fields, clocks and siteId', () {
    final back = LibraryDocumentRecord.decode(
      LibraryDocumentRecord.encode(doc),
    );
    expect(back.id, 'doc1');
    expect(back.siteId, 'site1');
    expect(back.fields, doc.fields);
    expect(back.clocks, doc.clocks);
    expect(back.deleted, isFalse);
  });

  test('unknown top-level keys survive a round trip', () {
    final json = doc.toJson()..['futureKey'] = {'a': 1};
    final back = LibraryDocumentRecord.fromJson(json);
    expect(back.toJson()['futureKey'], {'a': 1});
  });

  test('a key in neverTravels is dropped on read and never written', () {
    final json = doc.toJson();
    (json['fields'] as Map)['diverId'] = 'd1';
    (json['fields'] as Map)['isPrimary'] = true;
    (json['clocks'] as Map)['phone'] = c(9, 'm1').toJson();
    final back = LibraryDocumentRecord.fromJson(json);
    expect(back.fields.containsKey('diverId'), isFalse);
    expect(back.fields.containsKey('isPrimary'), isFalse);
    expect(back.clocks.containsKey('phone'), isFalse);
    final written = LibraryDocumentRecord(
      id: 'doc1',
      siteId: 'site1',
      fields: const {'reminderLeadDays': 3, 'title': 'A'},
      clocks: {'reminderLeadDays': c(1, 'm1')},
    ).toJson();
    expect((written['fields'] as Map).containsKey('reminderLeadDays'), isFalse);
    expect((written['clocks'] as Map).containsKey('reminderLeadDays'), isFalse);
  });

  test('a document without siteId or id throws FormatException', () {
    final noSite = doc.toJson()..remove('siteId');
    expect(() => LibraryDocumentRecord.fromJson(noSite), throwsFormatException);
    final noId = doc.toJson()..['id'] = '';
    expect(() => LibraryDocumentRecord.fromJson(noId), throwsFormatException);
  });

  test('LibraryPageRef.listFrom skips an entry with an unsafe fileId', () {
    final refs = LibraryPageRef.listFrom([
      page(),
      page(fileId: '../escape'),
      'not a page',
      {'id': 'p3'},
    ]);
    expect(refs, hasLength(1));
    expect(refs.single.fileId, 'f1');
    expect(refs.single.toJson(), page());
  });

  test('toJson writes formatVersion 2 and the signature domain is its own', () {
    expect(doc.toJson()['formatVersion'], 2);
    expect(doc.signatureDomain, 'ssl-doc-field:v1');
    expect(
      jsonDecode(utf8.decode(LibraryDocumentRecord.encode(doc)))['siteId'],
      'site1',
    );
  });

  test('withContent keeps the id and site', () {
    final moved = doc.withContent(
      deleted: true,
      fields: const {},
      clocks: const {},
      extra: const {},
    );
    expect(moved.id, 'doc1');
    expect(moved.siteId, 'site1');
    expect(moved.deleted, isTrue);
  });
}
