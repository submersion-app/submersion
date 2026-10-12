import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_merge.dart';
import 'package:submersion/core/services/sync/hlc.dart';

FieldClock c(int t, String m) => FieldClock(hlc: Hlc(t, 0, m), memberId: m);

void main() {
  test('each field goes to the newer clock; a tie keeps local', () {
    final local = SiteDocument(
      id: 's',
      fields: {'hazards': 'current', 'parkingInfo': 'lot A', 'notes': 'same'},
      clocks: {
        'hazards': c(10, 'a'),
        'parkingInfo': c(2, 'a'),
        'notes': c(5, 'a'),
      },
    );
    final remote = SiteDocument(
      id: 's',
      fields: {'hazards': 'none', 'parkingInfo': 'lot B', 'notes': 'other'},
      clocks: {
        'hazards': c(3, 'b'),
        'parkingInfo': c(9, 'b'),
        'notes': c(5, 'b'),
      },
    );
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.merged.fields['hazards'], 'current');
    expect(out.merged.fields['parkingInfo'], 'lot B');
    expect(
      out.merged.fields['notes'],
      'other',
      reason: 'b > a breaks the tie by node id',
    );
    expect(out.remoteWon, {'parkingInfo', 'notes'});
    expect(out.localWon, {'hazards'});
    expect(out.merged.clocks['parkingInfo'], c(9, 'b'));
  });

  test('an exact tie keeps local and uploads nothing', () {
    // The same clock is the same edit: a value that differs under it is
    // only this device's rendering (vocabulary spelling, list order).
    final local = SiteDocument(
      id: 's',
      fields: {'name': 'L'},
      clocks: {'name': c(5, 'a')},
    );
    final remote = SiteDocument(
      id: 's',
      fields: {'name': 'R'},
      clocks: {'name': c(5, 'a')},
    );
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.merged.fields['name'], 'L');
    expect(out.localWon, isEmpty);
    expect(out.remoteWon, isEmpty);
    expect(out.needsUpload, isFalse);
  });

  test('a list in another order under the same clock is not re-uploaded', () {
    // Two devices order a site's types by their own junction ids and spell
    // tags in their own vocabulary; neither may keep re-uploading.
    final local = SiteDocument(
      id: 's',
      fields: {
        'siteTypes': ['Wreck', 'Reef'],
        'tags': ['wreck dive'],
      },
      clocks: {'siteTypes': c(7, 'a'), 'tags': c(7, 'a')},
    );
    final remote = SiteDocument(
      id: 's',
      fields: {
        'siteTypes': ['Reef', 'Wreck'],
        'tags': ['Wreck Dive'],
      },
      clocks: {'siteTypes': c(7, 'a'), 'tags': c(7, 'a')},
    );
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.needsUpload, isFalse);
    expect(out.changesLocal, isFalse);
  });

  test('a field without a clock is oldest', () {
    final local = SiteDocument(
      id: 's',
      fields: {'name': 'L'},
      clocks: {'name': c(1, 'a')},
    );
    const remote = SiteDocument(id: 's', fields: {'name': 'R'});
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.merged.fields['name'], 'L');
    expect(out.localWon, {'name'});
  });

  test('a field only remote has is taken; one only local has is kept', () {
    final local = SiteDocument(
      id: 's',
      fields: {'notes': 'n'},
      clocks: {'notes': c(1, 'a')},
    );
    final remote = SiteDocument(
      id: 's',
      fields: {'hazards': 'h'},
      clocks: {'hazards': c(1, 'b')},
    );
    final out = mergeSiteDocuments(local: local, remote: remote);
    expect(out.merged.fields, {'notes': 'n', 'hazards': 'h'});
    expect(out.remoteWon, {'hazards'});
    expect(out.localWon, {'notes'});
  });

  test('deleted merges by its own clock', () {
    final local = SiteDocument(
      id: 's',
      deleted: false,
      clocks: {'deleted': c(1, 'a')},
    );
    final remote = SiteDocument(
      id: 's',
      deleted: true,
      clocks: {'deleted': c(2, 'b')},
    );
    expect(
      mergeSiteDocuments(local: local, remote: remote).merged.deleted,
      isTrue,
    );
    final undeleted = SiteDocument(
      id: 's',
      deleted: false,
      clocks: {'deleted': c(3, 'a')},
    );
    expect(
      mergeSiteDocuments(local: undeleted, remote: remote).merged.deleted,
      isFalse,
    );
  });

  test('identical documents need neither upload nor local change', () {
    final doc = SiteDocument(
      id: 's',
      fields: {'name': 'x'},
      clocks: {'name': c(1, 'a')},
    );
    final out = mergeSiteDocuments(local: doc, remote: doc);
    expect(out.needsUpload, isFalse);
    expect(out.changesLocal, isFalse);
  });

  test('merge is commutative and idempotent over random edits', () {
    final docs = [
      for (var m = 0; m < 3; m++)
        SiteDocument(
          id: 's',
          fields: {for (final f in SiteDocument.fieldNames) f: '$m-$f'},
          clocks: {
            for (final f in SiteDocument.fieldNames)
              f: c((f.hashCode * (m + 1)) % 97, 'm$m'),
          },
        ),
    ];
    final ab = mergeSiteDocuments(local: docs[0], remote: docs[1]).merged;
    final abc = mergeSiteDocuments(local: ab, remote: docs[2]).merged;
    final cb = mergeSiteDocuments(local: docs[2], remote: docs[1]).merged;
    final cba = mergeSiteDocuments(local: cb, remote: docs[0]).merged;
    expect(abc.toJson(), cba.toJson());
    expect(
      mergeSiteDocuments(local: abc, remote: abc).merged.toJson(),
      abc.toJson(),
    );
  });
}
