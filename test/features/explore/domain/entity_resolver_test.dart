import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/entity_resolver.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  NameEntry e(
    MentionKind k,
    String label,
    List<String> ids,
    NameTarget t, {
    int rank = 0,
    String? attrKey,
    String? attrChoice,
  }) => NameEntry(
    kind: k,
    label: label,
    ids: ids,
    target: t,
    rank: rank,
    attrKey: attrKey,
    attrChoice: attrChoice,
  );

  final index = NameIndex([
    e(MentionKind.place, 'Bonaire', ['s1', 's2', 's3'], NameTarget.sitePlace),
    e(
      MentionKind.place,
      'Netherlands Antilles',
      ['s1', 's2', 's3'],
      NameTarget.sitePlace,
      rank: 1,
    ),
    e(MentionKind.site, 'Salt Pier', ['s1'], NameTarget.siteId),
    e(MentionKind.site, 'Something Special', ['s2'], NameTarget.siteId),
    e(MentionKind.site, '1000 Steps', ['s3'], NameTarget.siteId),
    e(MentionKind.species, 'Green Turtle', ['sp1'], NameTarget.speciesId),
    e(
      MentionKind.species,
      'Green Turtle',
      ['sp1'],
      NameTarget.speciesId,
      rank: 1,
    ),
    e(
      MentionKind.species,
      'Chelonia mydas',
      ['sp1'],
      NameTarget.speciesId,
      rank: 2,
    ),
    e(MentionKind.species, 'Hawksbill Turtle', ['sp2'], NameTarget.speciesId),
    e(MentionKind.gear, 'Apeks MTX-R', ['g1'], NameTarget.equipmentId),
    e(
      MentionKind.gear,
      'Trilaminate',
      [],
      NameTarget.attrChoice,
      rank: 2,
      attrKey: 'shell_material',
      attrChoice: 'trilaminate',
    ),
    e(MentionKind.buddy, 'Sarah Jones', ['b1'], NameTarget.buddyId),
    e(MentionKind.buddy, 'Sarah Jonas', ['b2'], NameTarget.buddyId),
  ]);

  Resolution r(MentionKind k, String text) =>
      resolveMention(QueryMention(kind: k, text: text), index);

  test('an exact place resolves to the site id set', () {
    final res = r(MentionKind.place, 'Bonaire') as Resolved;
    expect(res.entry.target, NameTarget.sitePlace);
    expect(res.entry.ids, ['s1', 's2', 's3']);
    expect(res.score, 1.0);
  });

  test('a place that only matches a site name falls through to sites', () {
    final res = r(MentionKind.place, 'salt pier') as Resolved;
    expect(res.entry.target, NameTarget.siteId);
    expect(res.entry.ids, ['s1']);
  });

  test('diacritics and case are ignored', () {
    final res = r(MentionKind.site, 'SALT PIÉR') as Resolved;
    expect(res.entry.ids, ['s1']);
  });

  test('a species matched by several labels is one candidate', () {
    final res = r(MentionKind.species, 'green turtle');
    expect(res, isA<Resolved>());
    expect((res as Resolved).entry.ids, ['sp1']);
  });

  test('turtles alone is unresolved, not a guess', () {
    // Dice of "turtles" against "green turtle" and "hawksbill turtle" is well
    // below 0.75. The compiler surfaces candidates; the resolver is strict.
    expect(r(MentionKind.species, 'turtles'), isA<Unresolved>());
  });

  test('two near-equal buddies are ambiguous with both candidates', () {
    // "sarah jon" scores 0.889 against both names: a tie, not a guess.
    final res = r(MentionKind.buddy, 'Sarah Jon');
    expect(res, isA<Ambiguous>());
    final ids = (res as Ambiguous).candidates.map((c) => c.ids.single).toSet();
    expect(ids, {'b1', 'b2'});
  });

  test('gear resolves an attribute choice when no item matches', () {
    final res = r(MentionKind.gear, 'trilaminate suit');
    expect(res, isA<Resolved>());
    final entry = (res as Resolved).entry;
    expect(entry.target, NameTarget.attrChoice);
    expect(entry.attrKey, 'shell_material');
    expect(entry.attrChoice, 'trilaminate');
  });

  test('nothing similar is unresolved', () {
    expect(r(MentionKind.gear, 'submarine'), isA<Unresolved>());
    expect(
      resolveMention(
        const QueryMention(kind: MentionKind.tag, text: 'night'),
        NameIndex.empty,
      ),
      isA<Unresolved>(),
    );
  });
}
