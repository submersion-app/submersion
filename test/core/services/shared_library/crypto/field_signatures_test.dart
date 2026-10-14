import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/hlc.dart';

void main() {
  late LibrarySigningKey key;
  late LibrarySigningKey other;

  setUpAll(() async {
    key = await LibrarySigner.generate();
    other = await LibrarySigner.generate();
  });

  FieldClock clock(int t, [String member = 'm1']) =>
      FieldClock(hlc: Hlc(t, 0, member), memberId: member);

  Future<SiteDocument> signedDoc(Map<String, Object?> fields, int t) =>
      signOwnFields(
        SiteDocument(
          id: 's1',
          fields: fields,
          clocks: {for (final f in fields.keys) f: clock(t)},
        ),
        libraryId: 'L',
        memberId: 'm1',
        key: key,
      );

  test('a signed field verifies; a changed value does not', () async {
    final doc = await signedDoc({'name': 'A'}, 10);
    expect(doc.clocks['name']!.sig, isNotNull);
    final kept = await dropUnverified(
      doc,
      local: const SiteDocument(id: 's1'),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    expect(kept.fields['name'], 'A');
    final forged = SiteDocument(
      id: 's1',
      fields: const {'name': 'B'},
      clocks: doc.clocks,
    );
    final dropped = await dropUnverified(
      forged,
      local: const SiteDocument(id: 's1'),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    expect(dropped.fields.containsKey('name'), isFalse);
    expect(dropped.clocks.containsKey('name'), isFalse);
  });

  test('a field signed for another library or site does not verify', () async {
    final doc = await signedDoc({'name': 'A'}, 10);
    for (final (lib, site) in [('L2', 's1'), ('L', 's2')]) {
      final moved = await dropUnverified(
        SiteDocument(id: site, fields: doc.fields, clocks: doc.clocks),
        local: SiteDocument(id: site),
        libraryId: lib,
        approvedKeys: {'m1': key.publicKey},
      );
      expect(moved.fields, isEmpty);
    }
  });

  test('an unapproved signer and a missing signature are dropped', () async {
    final doc = await signedDoc({'name': 'A'}, 10);
    final notApproved = await dropUnverified(
      doc,
      local: const SiteDocument(id: 's1'),
      libraryId: 'L',
      approvedKeys: {'m1': other.publicKey},
    );
    expect(notApproved.fields, isEmpty);
    final unsigned = await dropUnverified(
      SiteDocument(
        id: 's1',
        fields: const {'name': 'A'},
        clocks: {'name': clock(10)},
      ),
      local: const SiteDocument(id: 's1'),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    expect(unsigned.fields, isEmpty);
  });

  test('a field not newer than the local one is not checked', () async {
    final remote = SiteDocument(
      id: 's1',
      fields: const {'name': 'A'},
      clocks: {'name': clock(10)},
    );
    final kept = await dropUnverified(
      remote,
      local: SiteDocument(
        id: 's1',
        fields: const {'name': 'A'},
        clocks: {'name': clock(10)},
      ),
      libraryId: 'L',
      approvedKeys: const {},
    );
    expect(kept.fields['name'], 'A');
  });

  test(
    'a value the local side lacks is checked even under its own clock',
    () async {
      final doc = await signedDoc({'name': 'A'}, 10);
      // A tombstone here keeps the clocks, not the values; the folder's
      // document was changed under the same clock.
      final changed = SiteDocument(
        id: 's1',
        fields: const {'name': 'B'},
        clocks: doc.clocks,
      );
      final kept = await dropUnverified(
        changed,
        local: SiteDocument(id: 's1', deleted: true, clocks: doc.clocks),
        libraryId: 'L',
        approvedKeys: {'m1': key.publicKey},
      );
      expect(kept.fields.containsKey('name'), isFalse);
      final genuine = await dropUnverified(
        doc,
        local: SiteDocument(id: 's1', deleted: true, clocks: doc.clocks),
        libraryId: 'L',
        approvedKeys: {'m1': key.publicKey},
      );
      expect(genuine.fields['name'], 'A');
    },
  );

  test('a forged tombstone is dropped', () async {
    final forged = SiteDocument(
      id: 's1',
      deleted: true,
      clocks: {SiteDocument.deletedField: clock(50, 'x')},
    );
    final kept = await dropUnverified(
      forged,
      local: const SiteDocument(id: 's1'),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    expect(kept.deleted, isFalse);
  });

  test('only the own member\'s unsigned clocks are signed', () async {
    final doc = await signOwnFields(
      SiteDocument(
        id: 's1',
        fields: const {'name': 'A', 'hazards': 'H'},
        clocks: {'name': clock(10), 'hazards': clock(11, 'm2')},
      ),
      libraryId: 'L',
      memberId: 'm1',
      key: key,
    );
    expect(doc.clocks['name']!.sig, isNotNull);
    expect(doc.clocks['hazards']!.sig, isNull);
  });

  test('signatures survive the document round trip', () async {
    final doc = await signedDoc({'name': 'A'}, 10);
    final again = SiteDocument.decode(SiteDocument.encode(doc));
    expect(again.clocks['name']!.sig, doc.clocks['name']!.sig);
  });

  test(
    'an edit by a member waiting for approval is held, not dropped',
    () async {
      final pending = await signOwnFields(
        SiteDocument(
          id: 's1',
          fields: const {'name': 'Theirs'},
          clocks: {'name': clock(20, 'p')},
        ),
        libraryId: 'L',
        memberId: 'p',
        key: other,
      );
      final local = SiteDocument(
        id: 's1',
        fields: const {'name': 'Mine'},
        clocks: {'name': clock(10)},
      );
      final held = await dropUnverified(
        pending,
        local: local,
        libraryId: 'L',
        approvedKeys: {'m1': key.publicKey},
        pendingKeys: {'p': other.publicKey},
      );
      // The local value and clock stand in: nothing applied, nothing missing.
      expect(held.fields['name'], 'Mine');
      expect(held.clocks['name'], local.clocks['name']);
      // And an upload carries the held edit forward.
      final carried = await carryHeld(
        local,
        pending,
        libraryId: 'L',
        pendingKeys: {'p': other.publicKey},
      );
      expect(carried.fields['name'], 'Theirs');
      expect(carried.clocks['name']!.memberId, 'p');
    },
  );

  test('a clock past the year 9999 proves nothing, signed or not', () async {
    // An approved member's own signature, on a time no device can reach:
    // taken, it would outlast every later edit.
    final doc = await signedDoc({'name': 'A'}, 300000000000000);
    final kept = await dropUnverified(
      doc,
      local: SiteDocument(
        id: 's1',
        fields: const {'name': 'B'},
        clocks: {'name': clock(10)},
      ),
      libraryId: 'L',
      approvedKeys: {'m1': key.publicKey},
    );
    // Absent, as any unproven field: the local value wins the merge.
    expect(kept.fields.containsKey('name'), isFalse);
    final carried = await carryHeld(
      SiteDocument(
        id: 's1',
        fields: const {'name': 'B'},
        clocks: {'name': clock(10)},
      ),
      doc,
      libraryId: 'L',
      pendingKeys: {'m1': key.publicKey},
    );
    expect(carried.fields['name'], 'B');
  });
}
