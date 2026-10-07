import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

/// The built-in refresher rules (issue #2267) cover every rung of their
/// agencies' ladders, professional rungs included. The seed stores resolved
/// level names, so this pins the seed to the catalog it was resolved from: a
/// rung added to a ladder later shows up here as a deliberate choice rather
/// than a silent gap.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<({Set<CertificationAgency> agencies, Set<CertificationLevel> levels})>
  scopeOf(String id) async {
    final row = await db
        .customSelect(
          'SELECT applicable_agencies, applicable_levels '
          'FROM certification_currency_rules WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return (
      agencies: CurrencyScopeCodec.decodeAgencies(
        row.read<String>('applicable_agencies'),
      ).toSet(),
      levels: CurrencyScopeCodec.decodeLevels(
        row.read<String>('applicable_levels'),
      ).toSet(),
    );
  }

  Set<CertificationLevel> laddersOf(Iterable<CertificationAgency> agencies) => {
    for (final a in agencies) ...CertificationLevelCatalog.ladderFor(a),
  };

  for (final id in const [
    'padi_reactivate',
    'ssi_skills_update',
    'generic_refresher',
  ]) {
    test('$id covers every ladder rung of its agencies', () async {
      final scope = await scopeOf(id);
      expect(scope.agencies, isNotEmpty);
      expect(scope.levels, laddersOf(scope.agencies));
    });
  }

  test('tdi_refresher covers its own ladder plus the three old generic '
      'rungs it deliberately leaves unrewritten (issue #3072)', () async {
    final scope = await scopeOf('tdi_refresher');
    expect(scope.agencies, {CertificationAgency.tdi});
    expect(
      scope.levels,
      laddersOf(scope.agencies).union({
        // Deliberately unmigrated: generic_refresher dropped TDI, so an old
        // 'cave'/'rebreather'/'instructor' certification needs its activity
        // clock here instead, not a guess at which new TDI course it meant.
        CertificationLevel.cave,
        CertificationLevel.rebreather,
        CertificationLevel.instructor,
      }),
    );
  });

  test('no refresher matches a dated safety credential', () async {
    for (final id in const [
      'padi_reactivate',
      'ssi_skills_update',
      'generic_refresher',
      'tdi_refresher',
    ]) {
      final scope = await scopeOf(id);
      expect(
        scope.levels.intersection({
          CertificationLevel.firstAid,
          CertificationLevel.oxygenProvider,
        }),
        isEmpty,
        reason: '$id: first aid lapses on a date, not on inactivity',
      );
    }
  });

  // A new agency (ACUC and DAN arrived in #690) must be a deliberate choice
  // here, not a card that silently never warns.
  test('every agency with a diver ladder has a refresher', () async {
    final covered = <CertificationAgency>{
      for (final id in const [
        'padi_reactivate',
        'ssi_skills_update',
        'generic_refresher',
        'tdi_refresher',
      ])
        ...(await scopeOf(id)).agencies,
    };
    // GUE revalidates on a date of its own; DAN issues no diver grades.
    final expected = CertificationAgency.values.toSet()
      ..removeAll({CertificationAgency.gue, CertificationAgency.dan});
    expect(covered, containsAll(expected));
  });

  test('first aid renewal covers every DAN provider credential', () async {
    final scope = await scopeOf('first_aid_24mo');
    final danProvider = {
      ...CertificationLevelCatalog.ladderFor(CertificationAgency.dan),
      ...CertificationLevelCatalog.specialtiesFor(CertificationAgency.dan),
    }.where((l) => !l.isInstructorLevel);
    expect(scope.agencies, isEmpty, reason: 'any agency issues first aid');
    expect(scope.levels, containsAll(danProvider));
  });

  test('membership renewal covers every instructor rating of its agencies, '
      'ACUC and DAN included', () async {
    final scope = await scopeOf('pro_membership_annual');
    expect(
      scope.agencies,
      containsAll({CertificationAgency.acuc, CertificationAgency.dan}),
    );
    final instructorRatings = laddersOf(
      scope.agencies,
    ).where((l) => l.isInstructorLevel);
    expect(scope.levels, containsAll(instructorRatings));
  });
}
