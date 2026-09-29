import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Every resolved buddy is an exact match. A name-substring filter would let
/// "Ana" match Diana and "Bob" match Bobby, while the chips claim two exact
/// buddies.
void main() {
  const units = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );
  final names = NameIndex(const [
    NameEntry(
      subject: QuerySubject.buddies,
      label: 'Ana',
      ids: ['b-ana'],
      target: NameTarget.buddyId,
    ),
    NameEntry(
      subject: QuerySubject.buddies,
      label: 'Bob',
      ids: ['b-bob'],
      target: NameTarget.buddyId,
    ),
    NameEntry(
      subject: QuerySubject.buddies,
      label: 'Smith, John',
      ids: [],
      target: NameTarget.legacyBuddyName,
      rank: 1,
    ),
  ]);

  ExploreCompilation compile(List<String> buddies) => ExploreCompiler.compile(
    ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': 'dives',
      'mentions': [
        for (final b in buddies) {'kind': 'buddy', 'text': b},
      ],
    }),
    ExploreCompilerContext(
      units: units,
      names: names,
      now: DateTime(2026, 9, 28),
    ),
  );

  test('one buddy stays the plain exact buddy axis', () {
    final f = compile(['Ana']).filter;
    expect(f.buddyId, 'b-ana');
    expect(f.buddyNameFilter, isNull);
    expect(f.query, isNull);
  });

  test('a second buddy is a second exact condition, not a name search', () {
    final f = compile(['Ana', 'Bob']).filter;
    expect(f.buddyId, 'b-ana');
    expect(f.buddyNameFilter, isNull);
    expect(
      f.query,
      ConditionNode(
        FieldPath(['buddies']),
        QueryOp.eq,
        const RefValue('b-bob', 'Bob'),
      ),
    );
  });

  test('three buddies AND together', () {
    final withCarl = NameIndex(const [
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'Ana',
        ids: ['b-ana'],
        target: NameTarget.buddyId,
      ),
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'Bob',
        ids: ['b-bob'],
        target: NameTarget.buddyId,
      ),
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'Carl',
        ids: ['b-carl'],
        target: NameTarget.buddyId,
      ),
    ]);
    final f = ExploreCompiler.compile(
      ParsedQuery.fromJson({
        'schemaVersion': kQuerySchemaVersion,
        'subject': 'dives',
        'mentions': [
          {'kind': 'buddy', 'text': 'Ana'},
          {'kind': 'buddy', 'text': 'Bob'},
          {'kind': 'buddy', 'text': 'Carl'},
        ],
      }),
      ExploreCompilerContext(
        units: units,
        names: withCarl,
        now: DateTime(2026, 9, 28),
      ),
    ).filter;
    expect(f.buddyId, 'b-ana');
    expect(
      f.query,
      AndNode([
        ConditionNode(
          FieldPath(['buddies']),
          QueryOp.eq,
          const RefValue('b-bob', 'Bob'),
        ),
        ConditionNode(
          FieldPath(['buddies']),
          QueryOp.eq,
          const RefValue('b-carl', 'Carl'),
        ),
      ]),
    );
  });

  test('a legacy name with a comma stays one exact condition', () {
    // The name filter splits on commas, which would turn one stored value
    // into two independent substring tests.
    final f = compile(['Smith, John']).filter;
    expect(f.buddyNameFilter, isNull);
    expect(
      f.query,
      ConditionNode(
        FieldPath(['legacyBuddy']),
        QueryOp.eq,
        const StringValue('Smith, John'),
      ),
    );
  });
}
