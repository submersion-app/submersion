import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_roles/data/diver_role_set_sql.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';

import '../../../helpers/test_database.dart';

/// Issue #4409: the SQL form of a dive's own role set must agree with
/// `DiveRoleSet.resolve`, the rule the app reads a dive's roles by, on every
/// shape the scalar column and the junction rows can take.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // Two custom role ids; uuidA sorts before uuidB.
  const uuidA = '0a000000-0000-4000-8000-000000000000';
  const uuidB = '0b000000-0000-4000-8000-000000000000';
  const universe = [...DiveRole.builtInIds, uuidA, uuidB];

  final cases = <({String name, String? scalar, List<String> junction})>[
    (
      name: 'null scalar ignores junction',
      scalar: null,
      junction: ['instructor'],
    ),
    (name: 'blank scalar', scalar: '', junction: []),
    (name: 'scalar only', scalar: 'instructor', junction: []),
    (
      name: 'current junction',
      scalar: 'instructor',
      junction: ['instructor', 'safetyDiver'],
    ),
    (
      name: 'stale junction: primary is instructor',
      scalar: 'buddy',
      junction: ['instructor', 'buddy'],
    ),
    (name: 'solo alone', scalar: 'solo', junction: ['solo']),
    (
      name: 'stale junction: solo dropped beside buddy',
      scalar: 'solo',
      junction: ['solo', 'buddy'],
    ),
    (
      name: 'solo dropped beside instructor',
      scalar: 'instructor',
      junction: ['instructor', 'solo'],
    ),
    (
      name: 'stale junction: custom ids sort ascending',
      scalar: uuidB,
      junction: [uuidB, uuidA],
    ),
    (
      name: 'custom primary ahead of buddy',
      scalar: uuidA,
      junction: [uuidA, uuidB, 'buddy'],
    ),
    // Duplicate rows cannot exist: idx_dive_diver_roles_dive_role_unique.
    (
      name: 'blank junction row ignored',
      scalar: 'instructor',
      junction: ['', 'instructor', 'student'],
    ),
  ];

  Future<void> seed(
    String diveId,
    String? scalar,
    List<String> junction,
  ) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diverRole: Value(scalar),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final (i, roleId) in junction.indexed) {
      await db
          .into(db.diveDiverRoles)
          .insert(
            DiveDiverRolesCompanion(
              id: Value('$diveId-$i'),
              diveId: Value(diveId),
              roleId: Value(roleId),
              createdAt: Value(now),
            ),
          );
    }
  }

  Future<Set<String>> sqlRoles(String diveId) async {
    final sql = diverRoleIdsOfDiveSql(diveId: 'd.id', scalar: 'd.diver_role');
    final held = <String>{};
    for (final roleId in universe) {
      final rows = await db
          .customSelect(
            'SELECT d.id FROM dives d WHERE d.id = ? AND ? IN ($sql)',
            variables: [Variable(diveId), Variable(roleId)],
          )
          .get();
      if (rows.isNotEmpty) held.add(roleId);
    }
    return held;
  }

  for (final (i, c) in cases.indexed) {
    test(
      'diverRoleIdsOfDiveSql matches DiveRoleSet.resolve: ${c.name}',
      () async {
        final diveId = 'dive-$i';
        await seed(diveId, c.scalar, c.junction);
        final expected = DiveRoleSet.resolve(
          scalar: c.scalar,
          junction: c.junction,
        ).toSet();
        expect(await sqlRoles(diveId), expected);
      },
    );
  }
}
