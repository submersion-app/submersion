import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';

NameEntry _row(
  QuerySubject subject,
  String id,
  String label, {
  bool primary = true,
  int rank = 0,
}) => NameEntry(
  subject: subject,
  label: label,
  ids: [id],
  target: rowTargetFor(subject),
  primary: primary,
  rank: rank,
);

void main() {
  test('fromRefs holds one primary row per ref', () {
    final index = NameIndex.fromRefs({
      QuerySubject.sites: const [RefValue('s1', 'Salt Pier')],
    });
    expect(index.refs(QuerySubject.sites), const [RefValue('s1', 'Salt Pier')]);
    expect(index.labelOf(QuerySubject.sites, 's1'), 'Salt Pier');
    expect(
      index.resolve(QuerySubject.sites, ' salt pier '),
      const RefValue('s1', 'Salt Pier'),
    );
  });

  test('fromRefs takes any ref subject, not only the loaded ones', () {
    final index = NameIndex.fromRefs(const {
      QuerySubject.certifications: [RefValue('c1', 'Rescue Diver')],
    });
    expect(index.labelOf(QuerySubject.certifications, 'c1'), 'Rescue Diver');
    expect(rowTargetFor(QuerySubject.certifications), NameTarget.row);
  });

  test(
    'an alternate label resolves to the row and prints the primary label',
    () {
      final index = NameIndex([
        _row(QuerySubject.species, 'sp1', 'Green sea turtle', rank: 1),
        _row(
          QuerySubject.species,
          'sp1',
          'Gruene Meeresschildkroete',
          primary: false,
        ),
        _row(
          QuerySubject.species,
          'sp1',
          'Chelonia mydas',
          primary: false,
          rank: 2,
        ),
      ]);
      expect(
        index.resolve(QuerySubject.species, 'gruene meeresschildkroete'),
        const RefValue('sp1', 'Green sea turtle'),
      );
      expect(
        index.resolve(QuerySubject.species, 'Chelonia mydas'),
        const RefValue('sp1', 'Green sea turtle'),
      );
      expect(index.refs(QuerySubject.species), const [
        RefValue('sp1', 'Green sea turtle'),
      ]);
    },
  );

  test('a primary name wins over another row\'s alternate', () {
    final index = NameIndex([
      _row(
        QuerySubject.equipment,
        'e2',
        'Apeks XTX50',
        primary: false,
        rank: 1,
      ),
      _row(QuerySubject.equipment, 'e1', 'Apeks XTX50'),
    ]);
    expect(index.resolve(QuerySubject.equipment, 'Apeks XTX50')!.id, 'e1');
  });

  test('sentence-only entries never resolve a typed ref', () {
    final index = NameIndex(const [
      NameEntry(
        subject: QuerySubject.sites,
        label: 'Bonaire',
        ids: ['s1', 's2'],
        target: NameTarget.sitePlace,
        placeFields: ['island'],
      ),
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'Bob',
        ids: [],
        target: NameTarget.legacyBuddyName,
        rank: 1,
      ),
    ]);
    expect(index.resolve(QuerySubject.sites, 'Bonaire'), isNull);
    expect(index.resolve(QuerySubject.buddies, 'Bob'), isNull);
    expect(index.refs(QuerySubject.sites), isEmpty);
    expect(index.forSubject(QuerySubject.sites), hasLength(1));
  });

  test('identity keeps its stored format', () {
    const buddy = NameEntry(
      subject: QuerySubject.buddies,
      label: 'Ana',
      ids: ['b1'],
      target: NameTarget.buddyId,
    );
    const legacy = NameEntry(
      subject: QuerySubject.buddies,
      label: 'Bob',
      ids: [],
      target: NameTarget.legacyBuddyName,
    );
    const choice = NameEntry(
      subject: QuerySubject.equipment,
      label: 'Trilaminate',
      ids: [],
      target: NameTarget.attrChoice,
      attrKey: 'material',
      attrChoice: 'trilaminate',
    );
    expect(buddy.identity, 'buddyId:b1:::');
    expect(legacy.identity, 'legacyBuddyName::::Bob');
    expect(choice.identity, 'attrChoice::material:trilaminate:');
  });

  test('candidates suggest row labels only', () {
    final index = NameIndex([
      _row(QuerySubject.sites, 's1', 'Salt Pier'),
      const NameEntry(
        subject: QuerySubject.sites,
        label: 'Salt Island',
        ids: ['s9'],
        target: NameTarget.sitePlace,
        placeFields: ['island'],
      ),
    ]);
    expect(index.candidates(QuerySubject.sites, 'Salt Pie'), ['Salt Pier']);
  });
}
