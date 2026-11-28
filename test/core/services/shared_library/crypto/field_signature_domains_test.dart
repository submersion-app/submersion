import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/clocked_record.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/hlc.dart';

/// A record signed under another domain, standing in for a library
/// document (issue #4713) without depending on its codec.
class _DocRecord extends ClockedRecord {
  const _DocRecord({
    required this.id,
    this.deleted = false,
    this.fields = const {},
    this.clocks = const {},
  });

  @override
  final String id;
  @override
  final bool deleted;
  @override
  final Map<String, Object?> fields;
  @override
  final Map<String, FieldClock> clocks;
  @override
  Map<String, Object?> get extra => const {};
  @override
  String get signatureDomain => 'ssl-doc-field:v1';

  @override
  _DocRecord withContent({
    required bool deleted,
    required Map<String, Object?> fields,
    required Map<String, FieldClock> clocks,
    required Map<String, Object?> extra,
  }) => _DocRecord(id: id, deleted: deleted, fields: fields, clocks: clocks);
}

void main() {
  late LibrarySigningKey key;

  setUpAll(() async => key = await LibrarySigner.generate());

  FieldClock clock(int t) => FieldClock(hlc: Hlc(t, 0, 'm1'), memberId: 'm1');

  test('site signature bytes are unchanged', () {
    final message = fieldSignatureMessage(
      domain: SiteDocument.signatureTag,
      libraryId: 'L',
      recordId: 's1',
      field: 'name',
      hlc: '0000000000010:0000:m',
      memberId: 'm',
      value: 'Reef',
    );
    expect(
      base64.encode(message),
      'c3NsLWZpZWxkOnYxCkwKczEKbmFtZQowMDAwMDAwMDAwMDEwOjAwMDA6bQptCmZlNzlm'
      'MGVmMTY2NWY4NmM4ODgwYmQ3OWYzYWMxNGUyNWI4ZjcwOGZkN2MzZDhjZmZiMDc5ZTI4'
      'M2U2OWRkY2I=',
    );
  });

  test('a site field signature does not verify as a document field', () async {
    final site = await signOwnFields(
      SiteDocument(
        id: 'x1',
        fields: const {'title': 'Access'},
        clocks: {'title': clock(10)},
      ),
      libraryId: 'L',
      memberId: 'm1',
      key: key,
    );
    final keptAsSite = await dropUnverified(
      site,
      local: const SiteDocument(id: 'x1'),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    expect(keptAsSite.fields['title'], 'Access');

    final replayed = _DocRecord(
      id: 'x1',
      fields: site.fields,
      clocks: site.clocks,
    );
    final checked = await dropUnverified(
      replayed,
      local: const _DocRecord(id: 'x1'),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    expect(checked, isA<_DocRecord>());
    expect(checked.fields.containsKey('title'), isFalse);
  });

  test('a document field signed as a document verifies', () async {
    final doc = await signOwnFields(
      _DocRecord(
        id: 'x1',
        fields: const {'title': 'Access'},
        clocks: {'title': clock(10)},
      ),
      libraryId: 'L',
      memberId: 'm1',
      key: key,
    );
    final checked = await dropUnverified(
      doc,
      local: const _DocRecord(id: 'x1'),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    expect(checked.fields['title'], 'Access');
  });

  test('records of either kind merge with the same rules', () {
    final out = mergeClockedRecords(
      local: _DocRecord(
        id: 'x1',
        fields: const {'title': 'Old'},
        clocks: {'title': clock(1)},
      ),
      remote: _DocRecord(
        id: 'x1',
        fields: const {'title': 'New'},
        clocks: {'title': clock(2)},
      ),
    );
    expect(out.merged, isA<_DocRecord>());
    expect(out.merged.fields['title'], 'New');
    expect(out.remoteWon, {'title'});
  });

  test(
    'a document refiled under another site loses its signed fields',
    () async {
      final doc = await signOwnFields(
        LibraryDocumentRecord(
          id: 'x1',
          siteId: 's1',
          fields: const {'title': 'Access'},
          clocks: {'title': clock(10)},
        ),
        libraryId: 'L',
        memberId: 'm1',
        key: key,
      );
      final kept = await dropUnverified(
        doc,
        local: const LibraryDocumentRecord(id: 'x1', siteId: 's1'),
        libraryId: 'L',
        approvedKeys: {'m1': key.publicKey},
      );
      expect(kept.fields['title'], 'Access');
      final moved = LibraryDocumentRecord(
        id: 'x1',
        siteId: 's2',
        fields: doc.fields,
        clocks: doc.clocks,
      );
      final checked = await dropUnverified(
        moved,
        local: const LibraryDocumentRecord(id: 'x1', siteId: 's2'),
        libraryId: 'L',
        approvedKeys: {'m1': key.publicKey},
      );
      expect(checked.fields.containsKey('title'), isFalse);
    },
  );
}
