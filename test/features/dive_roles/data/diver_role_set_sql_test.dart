import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_roles/data/diver_role_set_sql.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
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

  // The one "no role" rule (#4409): the Not set bar counts by it, its
  // drill-in (`role isEmpty`) matches by it, and the role set guards by it,
  // so a bar always equals the dives it opens.
  for (final scalar in [null, '', ' ', 'solo', uuidA]) {
    test('diverRoleUnsetSql matches DiveRoleSet.resolve: "$scalar"', () async {
      final row = await db
          .customSelect(
            'SELECT ${diverRoleUnsetSql('x.r')} AS unset FROM (SELECT ? AS r) x',
            variables: [Variable<String>(scalar)],
          )
          .getSingle();
      final expected = DiveRoleSet.resolve(
        scalar: scalar,
        junction: const [],
      ).isEmpty;
      expect(row.read<int>('unset') == 1, expected);
    });
  }

  // diveRoleVisibleSql must agree with resolveDiveRole (#1806): a dive keeps
  // a built-in role, an ownerless one and its owner's own; another diver's
  // custom role is shown as synthetic, so neither the card nor the relation
  // counts it.
  final epoch = DateTime(2020);
  final visibility =
      <({String name, bool builtIn, String? roleOwner, String? diveOwner})>[
        (
          name: 'built-in role',
          builtIn: true,
          roleOwner: null,
          diveOwner: 'me',
        ),
        (
          name: 'ownerless custom role',
          builtIn: false,
          roleOwner: null,
          diveOwner: 'me',
        ),
        (
          name: 'own custom role',
          builtIn: false,
          roleOwner: 'me',
          diveOwner: 'me',
        ),
        (
          name: 'another diver\'s custom role',
          builtIn: false,
          roleOwner: 'other',
          diveOwner: 'me',
        ),
        (
          name: 'custom role on an ownerless dive',
          builtIn: false,
          roleOwner: 'other',
          diveOwner: null,
        ),
      ];
  for (final v in visibility) {
    test('diveRoleVisibleSql matches resolveDiveRole: ${v.name}', () async {
      final role = DiveRole(
        id: 'r',
        diverId: v.roleOwner,
        name: 'R',
        isBuiltIn: v.builtIn,
        createdAt: epoch,
        updatedAt: epoch,
      );
      final kept = identical(
        resolveDiveRole({'r': role}, 'r', diveDiverId: v.diveOwner),
        role,
      );
      final row = await db
          .customSelect(
            'SELECT ${diveRoleVisibleSql(role: 'r', diveDiverId: 'x.owner')} '
            'AS visible FROM (SELECT ? AS is_built_in, ? AS diver_id) r, '
            '(SELECT ? AS owner) x',
            variables: [
              Variable<int>(v.builtIn ? 1 : 0),
              Variable<String>(v.roleOwner),
              Variable<String>(v.diveOwner),
            ],
          )
          .getSingle();
      expect(row.read<int>('visible') == 1, kept);
    });
  }
}
