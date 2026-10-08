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
    'pro_membership_annual': [
      'tdiTechnicalDivemaster',
      'tdiInstructor',
      'tdiInstructorTrainer',
      'tdiNonDivingSpecialtyInstructor',
    ],
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
      final certColumnNames = certColumns.map((c) => c.read<String>('name'));
      if (certColumnNames.contains('level')) {
        for (final entry in _unambiguousTdiLevelRewrites.entries) {
          await customStatement(
            "UPDATE certifications SET level = ? "
            "WHERE agency = 'tdi' AND level = ?",
            [entry.value, entry.key],
          );
        }
      }
      // A card's primary (agency, level) is its own columns, rewritten
      // above; a secondary TDI recognition lives in additional_credentials
      // (issue: dual credentials), a JSON array the currency engine reads
      // just as eagerly (Certification.credentials). The UPDATE above never
      // reaches these: a card whose own agency is, say, PADI, with TDI only
      // as a secondary credential, never matches "WHERE agency = 'tdi'".
      if (certColumnNames.contains('additional_credentials')) {
        await _rewriteSecondaryTdiCredentials();
      }
    }

    if (!await _tableExists('certification_currency_rules')) return;
    for (final entry in _currencyRuleLevelAdditions.entries) {
      await _rewriteBuiltInScope(
        ruleId: entry.key,
        column: 'applicable_levels',
        transform: (current) {
          final missing = entry.value.where((l) => !current.contains(l));
          return missing.isEmpty ? null : [...current, ...missing];
        },
      );
    }

    // generic_refresher's fresh seed (kSeedBuiltInCurrencyRulesSql) no
    // longer lists "tdi": TDI has its own tdi_refresher rule now, covering
    // its new ladder. INSERT OR IGNORE can add that new row but can never
    // rewrite generic_refresher's already-seeded one, so without this, an
    // upgraded database would keep "tdi" there forever while a fresh
    // install never has it -- the same kind of install-path drift the
    // additions above close, just a removal instead of an addition.
    await _rewriteBuiltInScope(
      ruleId: 'generic_refresher',
      column: 'applicable_agencies',
      transform: (current) => current.contains('tdi')
          ? current.where((a) => a != 'tdi').toList()
          : null,
    );
  }

  /// Rewrites a TDI entry inside additional_credentials the same way the
  /// primary (agency, level) columns are rewritten above, for cards whose
  /// TDI recognition is a secondary one. Tolerant of a malformed value the
  /// same way CertificationRepository's own decode is: a row this cannot
  /// parse as a JSON array is left untouched rather than failing the
  /// migration for every other row.
  Future<void> _rewriteSecondaryTdiCredentials() async {
    final rows = await customSelect(
      'SELECT id, additional_credentials FROM certifications '
      "WHERE additional_credentials IS NOT NULL "
      "AND additional_credentials != '' AND additional_credentials LIKE '%tdi%'",
    ).get();
    for (final row in rows) {
      final raw = row.read<String>('additional_credentials');
      List<dynamic> decoded;
      try {
        final parsed = jsonDecode(raw);
        if (parsed is! List) continue;
        decoded = parsed;
      } on FormatException {
        continue;
      }
      final rewritten = [for (final entry in decoded) _rewriteIfTdi(entry)];
      if (const DeepCollectionEquality().equals(rewritten, decoded)) continue;
      await customStatement(
        'UPDATE certifications SET additional_credentials = ? WHERE id = ?',
        [jsonEncode(rewritten), row.read<String>('id')],
      );
    }
  }

  /// [entry] rewritten if it is a TDI credential naming one of the eight
  /// unambiguous legacy levels, unchanged otherwise.
  dynamic _rewriteIfTdi(dynamic entry) {
    if (entry is! Map<String, dynamic>) return entry;
    final newLevel = _unambiguousTdiLevelRewrites[entry['level']];
    if (entry['agency'] != 'tdi' || newLevel == null) return entry;
    return {...entry, 'level': newLevel};
  }

  /// Reads [column] (a JSON scope array) of the built-in currency rule
  /// [ruleId], and writes it back only when [transform] returns a changed
  /// list; returning null means "nothing to change". Shared by the level
  /// additions and the agency removal above, which differ only in which
  /// column they touch and how they transform it.
  Future<void> _rewriteBuiltInScope({
    required String ruleId,
    required String column,
    required List<String>? Function(List<String> current) transform,
  }) async {
    final rows = await customSelect(
      'SELECT $column FROM certification_currency_rules '
      'WHERE id = ? AND is_built_in = 1',
      variables: [Variable<String>(ruleId)],
    ).get();
    if (rows.isEmpty) return;
    final current = CurrencyScopeCodec.decodeStrings(
      rows.first.read<String>(column),
    );
    final updated = transform(current);
    if (updated == null) return;
    await customStatement(
      'UPDATE certification_currency_rules SET $column = ? '
      'WHERE id = ? AND is_built_in = 1',
      [CurrencyScopeCodec.encode(updated), ruleId],
    );
  }
}
