import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

import 'explore_query_parts.dart';

/// Every resolved buddy is an exact match. A name-substring filter would let
/// "Ana" match Diana and "Bob" match Bobby, while the chips claim two exact
/// buddies.
void main() {
  const units = UnitPrefs(
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
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

  ConditionNode buddy(String id, String label) =>
      ConditionNode(FieldPath(['buddies']), QueryOp.eq, RefValue(id, label));

  test('one buddy is one exact buddy condition', () {
    expect(partsOf(compile(['Ana'])), [buddy('b-ana', 'Ana')]);
  });

  test('a second buddy is a second exact condition, not a name search', () {
    expect(partsOf(compile(['Ana', 'Bob'])), [
      buddy('b-ana', 'Ana'),
      buddy('b-bob', 'Bob'),
    ]);
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
    final c = ExploreCompiler.compile(
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
    );
    expect(partsOf(c), [
      buddy('b-ana', 'Ana'),
      buddy('b-bob', 'Bob'),
      buddy('b-carl', 'Carl'),
    ]);
  });

  test('a legacy name with a comma stays one exact condition', () {
    // The name filter splits on commas, which would turn one stored value
    // into two independent substring tests.
    expect(partsOf(compile(['Smith, John'])), [
      ConditionNode(
        FieldPath(['legacyBuddy']),
        QueryOp.eq,
        const StringValue('Smith, John'),
      ),
    ]);
  });
}
