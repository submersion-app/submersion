import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('every subject field resolves on its own registry root', () {
    for (final entry in kExploreSubjectFields.entries) {
      for (final f in entry.value) {
        expect(f.root, rootOf(entry.key), reason: f.name);
        expect(f.field, isNotNull, reason: '${entry.key.name}.${f.name}');
      }
    }
  });

  test('a field over all of the row\'s dives says it is an aggregate', () {
    // The compiler unplaces an aggregate beside a dive scope; one it does
    // not know about would silently answer over all time instead.
    for (final f in [
      ...kExploreFields,
      ...kExploreSubjectFields.values.expand((l) => l),
    ]) {
      final overDives = f.field?.sql.contains('FROM dives ad') ?? false;
      expect(f.aggregate, overDives, reason: '${f.root.name}.${f.name}');
    }
  });

  test('the kinds match the registry types', () {
    for (final f in kExploreSubjectFields.values.expand((l) => l)) {
      final type = f.field!.type;
      switch (f.kind) {
        case ExploreValueKind.number:
          expect(type, FieldType.number, reason: f.name);
        case ExploreValueKind.enumName:
          expect(type, FieldType.enumName, reason: f.name);
          expect(f.enumValues, isNotEmpty, reason: f.name);
        case ExploreValueKind.flag:
          expect(type, FieldType.bool, reason: f.name);
        case ExploreValueKind.date || ExploreValueKind.days:
          expect(type, FieldType.date, reason: f.name);
        case ExploreValueKind.typeName:
          fail('no subject field names a type: ${f.name}');
      }
    }
  });

  test("a subject's own word wins; any other dive word goes via dives", () {
    final rating = exploreFieldFor(ParsedSubject.sites, 'rating')!;
    expect(rating.viaDives, isFalse);
    expect(rating.field.root, QuerySubject.sites);

    final depth = exploreFieldFor(ParsedSubject.sites, 'depth')!;
    expect(depth.field.path, ['maxDepth']);
    expect(depth.field.dimension, FieldDimension.depth);

    final water = exploreFieldFor(ParsedSubject.sites, 'waterTemp')!;
    expect(water.viaDives, isTrue);
    expect(water.field.root, QuerySubject.dives);

    final diveRating = exploreFieldFor(ParsedSubject.dives, 'rating')!;
    expect(diveRating.viaDives, isFalse);
    expect(diveRating.field.root, QuerySubject.dives);

    expect(exploreFieldFor(ParsedSubject.buddies, 'nonsense'), isNull);
    // Another subject's own word is unknown here, not borrowed.
    expect(exploreFieldFor(ParsedSubject.buddies, 'gearType'), isNull);
  });

  test('the field words are every field once, dives first', () {
    final names = exploreFieldNames();
    expect(names.toSet().length, names.length);
    expect(names.take(kExploreFields.length), [
      for (final f in kExploreFields) f.name,
    ]);
    for (final f in kExploreSubjectFields.values.expand((l) => l)) {
      expect(names, contains(f.name));
    }
  });
}
