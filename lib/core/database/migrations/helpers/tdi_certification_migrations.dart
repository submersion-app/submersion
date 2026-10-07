part of '../app_database_migrations.dart';

/// TDI's own certification structure (issue #3072), replacing the generic
/// tech ladder it used to share with IANTD and PSAI.
///
/// One-shot data fixes, deliberately NOT re-asserted in beforeOpen: same
/// convention as the bottom-time heuristic repair. A device that reaches
/// this version by restore or sync-adopt skips them, same as any other
/// one-shot data fix in this ladder.
extension TdiCertificationMigrations on AppDatabase {
  /// The eight old generic values a TDI certification unambiguously meant
  /// one, and only one, of TDI's new course names (issue #3072 design
  /// discussion). Deliberately excludes Tech Diver, Cave, Rebreather,
  /// Instructor and Wreck: TDI offers several distinct courses each of
  /// those could have meant, and guessing would fabricate a specific course
  /// the diver never logged. Those five keep rendering through the existing
  /// unknown-id fallback in CertificationCatalog.
  static const _unambiguousTdiLevelRewrites = {
    'nitrox': 'tdiNitroxDiver',
    'advancedNitrox': 'tdiAdvancedNitroxDiver',
    'decompression': 'tdiDecompressionProceduresDiver',
    'extendedRange': 'tdiExtendedRangeDiver',
    'trimix': 'tdiTrimixDiver',
    'advancedTrimix': 'tdiAdvancedTrimixDiver',
    'sidemount': 'tdiSidemountDiver',
    'cavern': 'tdiCavernDiver',
  };

  /// Built-in currency rules seeded before this version with a TDI-relevant
  /// scope (issue #2267 predates #3072). INSERT OR IGNORE can add the new
  /// `tdi_refresher` row but can never rewrite one of these four existing
  /// rows, so the new TDI level names they now need are merged in here,
  /// once, by id.
  static const _currencyRuleLevelAdditions = {
    'pro_membership_annual': ['tdiInstructor', 'tdiInstructorTrainer'],
    'deco_currency': [
      'tdiDecompressionProceduresDiver',
      'tdiTrimixDiver',
      'tdiAdvancedTrimixDiver',
      'tdiAdvancedNitroxDiver',
      'tdiExtendedRangeDiver',
      'tdiHelitroxDiver',
    ],
    'cave_currency': [
      'tdiCavernDiver',
      'tdiIntroToCaveDiver',
      'tdiFullCaveDiver',
      'tdiRebreatherCavernDiver',
      'tdiRebreatherIntroCaveDiver',
      'tdiRebreatherFullCaveDiver',
      'tdiCaveSurveyingDiver',
      'tdiStageCaveDiver',
      'tdiDpvCaveDiver',
    ],
    'rebreather_currency': [
      'tdiAirDiluentCcrDiver',
      'tdiSemiClosedRebreatherDiver',
      'tdiAirDiluentDecoCcrDiver',
      'tdiHelitroxCcrDiver',
      'tdiMixedGasCcrDiver',
      'tdiAdvancedMixedGasCcrDiver',
      'tdiRebreatherCavernDiver',
      'tdiRebreatherIntroCaveDiver',
      'tdiRebreatherFullCaveDiver',
    ],
  };

  /// v273: rewrites unambiguous legacy TDI certification levels to their
  /// new names and extends the currency rules that named the old ones
  /// (issue #3072). Idempotent: the UPDATE's WHERE clause stops matching
  /// once a row is rewritten, and the currency-rule merge only appends a
  /// name that is not already present.
  Future<void> _migrateTdiCertificationStructure() async {
    // Skipped on a partial migration-test fixture that predates the level
    // column, or lacks the table at all, the same guard as
    // _assertCertificationCurrencySchema uses for its own parent tables.
    if (await _tableExists('certifications')) {
      final certColumns = await customSelect(
        "PRAGMA table_info('certifications')",
      ).get();
      if (certColumns.any((c) => c.read<String>('name') == 'level')) {
        for (final entry in _unambiguousTdiLevelRewrites.entries) {
          await customStatement(
            "UPDATE certifications SET level = ? "
            "WHERE agency = 'tdi' AND level = ?",
            [entry.value, entry.key],
          );
        }
      }
    }

    if (!await _tableExists('certification_currency_rules')) return;
    for (final entry in _currencyRuleLevelAdditions.entries) {
      final rows = await customSelect(
        'SELECT applicable_levels FROM certification_currency_rules '
        'WHERE id = ? AND is_built_in = 1',
        variables: [Variable<String>(entry.key)],
      ).get();
      if (rows.isEmpty) continue;
      final current = CurrencyScopeCodec.decodeStrings(
        rows.first.read<String>('applicable_levels'),
      );
      final missing = entry.value.where((l) => !current.contains(l));
      if (missing.isEmpty) continue;
      final updated = CurrencyScopeCodec.encode([...current, ...missing]);
      await customStatement(
        'UPDATE certification_currency_rules SET applicable_levels = ? '
        'WHERE id = ? AND is_built_in = 1',
        [updated, entry.key],
      );
    }

    // generic_refresher's fresh seed (kSeedBuiltInCurrencyRulesSql) no
    // longer lists "tdi": TDI has its own tdi_refresher rule now, covering
    // its new ladder. INSERT OR IGNORE can add that new row but can never
    // rewrite generic_refresher's already-seeded one, so without this, an
    // upgraded database would keep "tdi" there forever while a fresh
    // install never has it -- the same kind of install-path drift the
    // additions above close, just a removal instead of an addition.
    final genericRefresherRows = await customSelect(
      "SELECT applicable_agencies FROM certification_currency_rules "
      "WHERE id = 'generic_refresher' AND is_built_in = 1",
    ).get();
    if (genericRefresherRows.isNotEmpty) {
      final agencies = CurrencyScopeCodec.decodeStrings(
        genericRefresherRows.first.read<String>('applicable_agencies'),
      );
      if (agencies.contains('tdi')) {
        await customStatement(
          "UPDATE certification_currency_rules SET applicable_agencies = ? "
          "WHERE id = 'generic_refresher' AND is_built_in = 1",
          [
            CurrencyScopeCodec.encode(
              agencies.where((a) => a != 'tdi').toList(),
            ),
          ],
        );
      }
    }
  }
}
