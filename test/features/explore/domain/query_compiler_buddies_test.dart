import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_compiler.dart';
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
  const names = NameIndex([
    NameEntry(
      kind: MentionKind.buddy,
      label: 'Ana',
      ids: ['b-ana'],
      target: NameTarget.buddyId,
    ),
    NameEntry(
      kind: MentionKind.buddy,
      label: 'Bob',
      ids: ['b-bob'],
      target: NameTarget.buddyId,
    ),
    NameEntry(
      kind: MentionKind.buddy,
      label: 'Smith, John',
      ids: [],
      target: NameTarget.legacyBuddyName,
      rank: 1,
    ),
  ]);

  CompiledQuery compile(List<String> buddies) => QueryCompiler.compile(
    ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': 'dives',
      'mentions': [
        for (final b in buddies) {'kind': 'buddy', 'text': b},
      ],
    }),
    CompilerContext(units: units, names: names, now: DateTime(2026, 9, 28)),
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
    const withCarl = NameIndex([
      NameEntry(
        kind: MentionKind.buddy,
        label: 'Ana',
        ids: ['b-ana'],
        target: NameTarget.buddyId,
      ),
      NameEntry(
        kind: MentionKind.buddy,
        label: 'Bob',
        ids: ['b-bob'],
        target: NameTarget.buddyId,
      ),
      NameEntry(
        kind: MentionKind.buddy,
        label: 'Carl',
        ids: ['b-carl'],
        target: NameTarget.buddyId,
      ),
    ]);
    final f = QueryCompiler.compile(
      ParsedQuery.fromJson({
        'schemaVersion': kQuerySchemaVersion,
        'subject': 'dives',
        'mentions': [
          {'kind': 'buddy', 'text': 'Ana'},
          {'kind': 'buddy', 'text': 'Bob'},
          {'kind': 'buddy', 'text': 'Carl'},
        ],
      }),
      CompilerContext(
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
