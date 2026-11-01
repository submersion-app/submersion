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

/// A site row that counts how often its label is read.
class _LabelCounting extends NameEntry {
  _LabelCounting(String label)
    : _label = label,
      super(
        subject: QuerySubject.sites,
        label: label,
        ids: [label],
        target: NameTarget.siteId,
        primary: true,
      );

  final String _label;
  int reads = 0;

  @override
  String get label {
    reads++;
    return _label;
  }
}

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

  test('entries of one rank keep their load order, however many', () {
    final rows = [
      for (var i = 0; i < 40; i++)
        _row(QuerySubject.buddies, 'b$i', 'Buddy', primary: i.isEven),
    ];
    final index = NameIndex(rows);
    final order = index
        .forSubject(QuerySubject.buddies)
        .map((e) => e.ids.single);
    expect(order, [
      for (var i = 0; i < 40; i += 2) 'b$i',
      for (var i = 1; i < 40; i += 2) 'b$i',
    ]);
    expect(index.resolve(QuerySubject.buddies, 'Buddy')!.id, 'b0');
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
    // Both labels start with this, so only the row filter tells them apart.
    expect(index.candidates(QuerySubject.sites, 'Salt'), ['Salt Pier']);
  });

  test('candidates offer a label two rows share once', () {
    final index = NameIndex([
      _row(QuerySubject.sites, 's1', 'Blue Hole'),
      _row(QuerySubject.sites, 's2', 'Blue Hole'),
    ]);
    expect(index.candidates(QuerySubject.sites, 'Blue Hol'), ['Blue Hole']);
  });

  test('candidates read the labels once, not on every edit (#3849)', () {
    final salt = _LabelCounting('Salt Pier');
    final blue = _LabelCounting('Blue Hole');
    final index = NameIndex([salt, blue]);
    salt.reads = blue.reads = 0;

    expect(index.candidates(QuerySubject.sites, 'Salt Pi'), ['Salt Pier']);
    final prepared = salt.reads + blue.reads;
    expect(prepared, greaterThan(0));

    expect(index.candidates(QuerySubject.sites, 'Salt Pir'), ['Salt Pier']);
    expect(index.candidates(QuerySubject.sites, 'Blue Hol'), ['Blue Hole']);
    expect(salt.reads + blue.reads, prepared);
  });

  test('candidates keep each subject to its own labels', () {
    final index = NameIndex([
      _row(QuerySubject.sites, 's1', 'Salt Pier'),
      _row(QuerySubject.buddies, 'b1', 'Salt Bae'),
    ]);
    expect(index.candidates(QuerySubject.sites, 'Salt'), ['Salt Pier']);
    expect(index.candidates(QuerySubject.buddies, 'Salt'), ['Salt Bae']);
    expect(index.candidates(QuerySubject.tags, 'Salt'), isEmpty);
  });

  test('an index built from another offers the added names', () {
    final base = NameIndex([_row(QuerySubject.sites, 's1', 'Salt Pier')]);
    expect(base.candidates(QuerySubject.sites, 'Salt'), ['Salt Pier']);

    final more = base.followedBy([_row(QuerySubject.sites, 's2', 'Salt Pond')]);
    expect(more.candidates(QuerySubject.sites, 'Salt'), [
      'Salt Pier',
      'Salt Pond',
    ]);
    expect(base.candidates(QuerySubject.sites, 'Salt'), ['Salt Pier']);
  });

  test('followedBy adds entries after its own, primaries still first', () {
    // Explore adds the legacy buddy names this way (#2641): a legacy text at
    // rank 1 sorts after every linked buddy's name, and after an alternate
    // of the same rank that was already there.
    final base = NameIndex([
      _row(QuerySubject.buddies, 'b2', 'Cid'),
      _row(QuerySubject.buddies, 'b1', 'Ana A', primary: false, rank: 1),
    ]);
    const legacy = NameEntry(
      subject: QuerySubject.buddies,
      label: 'Ana',
      ids: [],
      target: NameTarget.legacyBuddyName,
      rank: 1,
    );
    final index = base.followedBy(const [legacy]);
    expect(index.forSubject(QuerySubject.buddies).map((e) => e.label), [
      'Cid',
      'Ana A',
      'Ana',
    ]);
    expect(index.refs(QuerySubject.buddies), base.refs(QuerySubject.buddies));
    expect(base.entries, hasLength(2));
  });
}
