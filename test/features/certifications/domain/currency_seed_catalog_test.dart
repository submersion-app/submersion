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

  test('no refresher matches a dated safety credential', () async {
    for (final id in const [
      'padi_reactivate',
      'ssi_skills_update',
      'generic_refresher',
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
}
