part of '../app_database_migrations.dart';

/// Buddies, dive roles, certifications and courses.
extension BuddyMigrations on AppDatabase {
  /// Idempotent DDL for the issue #553 buddy-owner column on certifications.
  /// Called from the v109 onUpgrade block and the beforeOpen backstop.
  Future<void> _assertCertificationBuddyOwnerColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('certifications')",
    ).get();
    if (cols.isEmpty) return;
    final has = cols.any((c) => c.read<String>('name') == 'buddy_id');
    if (!has) {
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN buddy_id TEXT '
        'REFERENCES buddies (id) ON DELETE CASCADE',
      );
    }
  }

  /// v199: certifications.additional_credentials (JSON array of extra
  /// agency/level pairs). PRAGMA-guarded, idempotent -- called from the v199
  /// onUpgrade step and the beforeOpen backstop.
  Future<void> _assertCertificationCredentialsColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('certifications')",
    ).get();
    if (cols.isEmpty) return;
    final has = cols.any(
      (c) => c.read<String>('name') == 'additional_credentials',
    );
    if (!has) {
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN additional_credentials TEXT',
      );
    }
  }

  /// v223: buddies.linked_diver_id and dives.outing_id (issue #2002).
  /// Idempotent, so it is safe from both onUpgrade and the beforeOpen
  /// backstop, and a no-op for either table when it does not exist yet.
  /// SQLite lets ADD COLUMN carry a REFERENCES clause only for a nullable
  /// column with no default, which this one is.
  Future<void> _assertBuddyProfileDiveLinkColumns() async {
    final buddyCols = await customSelect("PRAGMA table_info('buddies')").get();
    if (buddyCols.isNotEmpty) {
      final names = buddyCols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('linked_diver_id')) {
        await customStatement(
          'ALTER TABLE buddies ADD COLUMN linked_diver_id TEXT '
          'REFERENCES divers (id) ON DELETE SET NULL',
        );
      }
    }
    final diveCols = await customSelect("PRAGMA table_info('dives')").get();
    if (diveCols.isNotEmpty) {
      final names = diveCols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('outing_id')) {
        await customStatement('ALTER TABLE dives ADD COLUMN outing_id TEXT');
      }
    }
  }

  /// Copy each buddy's inline certification into a certifications row owned by
  /// that buddy (issue #553). Invoked from the onUpgrade blocks only (v109
  /// expand + the v110 contract safety-net), NEVER the beforeOpen backstop --
  /// the inline columns survive until v110, and re-running the copy on every
  /// open would resurrect a user-deleted buddy cert. The id is deterministic
  /// (`buddycert-<buddyId>`) and the insert upserts, so independent per-device
  /// migrations converge to one row under sync instead of duplicating.
  Future<void> _migrateBuddyInlineCertifications() async {
    final buddyCols = await customSelect("PRAGMA table_info('buddies')").get();
    final names = buddyCols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('certification_level') &&
        !names.contains('certification_agency')) {
      return;
    }
    final rows = await customSelect(
      'SELECT id, certification_level, certification_agency FROM buddies '
      'WHERE certification_level IS NOT NULL '
      'OR certification_agency IS NOT NULL',
    ).get();
    for (final r in rows) {
      final buddyId = r.read<String>('id');
      final level = r.read<String?>('certification_level');
      final agency = r.read<String?>('certification_agency') ?? 'other';
      final certId = 'buddycert-$buddyId';
      final name = _displayNameForMigratedCert(level, agency);
      final now = DateTime.now().millisecondsSinceEpoch;
      await customStatement(
        'INSERT INTO certifications '
        '(id, buddy_id, diver_id, name, agency, level, notes, '
        'created_at, updated_at) '
        "VALUES (?, ?, NULL, ?, ?, ?, '', ?, ?) "
        'ON CONFLICT(id) DO UPDATE SET buddy_id = excluded.buddy_id',
        [certId, buddyId, name, agency, level, now, now],
      );
    }
  }

  /// Fold buddy professional credentials (buddy_roles, issue #395) into
  /// buddy-owned certifications rows, then drop the table (v147; spec
  /// 2026-08-08-buddy-professional-roles-fold). Invoked from onUpgrade AND
  /// as a guarded beforeOpen backstop -- unlike the #553 inline-cert copy
  /// (whose source columns survive until v110, so it must never run in
  /// beforeOpen), this helper's own DROP TABLE makes the sqlite_master guard
  /// below a strict no-op once buddy_roles is gone, so re-running it on
  /// every open cannot resurrect a user-deleted cert. The beforeOpen call
  /// exists purely to protect a DB whose user_version advanced past 145
  /// (parallel-branch schema-version collision) without ever running the
  /// v147 block, which would otherwise strand it with an orphaned
  /// buddy_roles table nothing else reads. Ids are deterministic
  /// (`buddyrolecert-<rowId>`): synced replicas share buddy_roles row ids,
  /// so independent per-device migrations converge on identical cert rows
  /// instead of duplicating.
  Future<void> _migrateBuddyRolesToCertifications() async {
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='buddy_roles'",
    ).get();
    if (tables.isEmpty) return;

    const levelForRole = {
      'instructor': 'instructor',
      'diveMaster': 'diveMaster',
      'diveGuide': 'diveGuide',
    };
    const nameForRole = {
      'instructor': 'Instructor',
      'diveMaster': 'Divemaster',
      'diveGuide': 'Dive Guide',
    };

    // JOIN buddies so an orphaned credential row (FK-off test databases)
    // can never fail the certifications FK on insert.
    final rows = await customSelect(
      'SELECT br.id, br.buddy_id, br.role, br.credential_number, br.agency, '
      'br.notes, br.created_at, br.updated_at '
      'FROM buddy_roles br JOIN buddies b ON b.id = br.buddy_id',
    ).get();
    for (final r in rows) {
      final role = r.read<String>('role');
      final level = levelForRole[role];
      if (level == null) continue; // unknown role: feature is gone, drop it
      final buddyId = r.read<String>('buddy_id');
      final agency = r.read<String?>('agency') ?? 'other';
      final cardNumber = r.read<String?>('credential_number');

      // ORDER BY id keeps the backfill target deterministic across replicas
      // when a buddy has multiple pre-existing certs at the same
      // (agency, level) -- this migration runs independently per device.
      final existing = await customSelect(
        'SELECT id, card_number FROM certifications '
        'WHERE buddy_id = ? AND agency = ? AND level = ? '
        'ORDER BY id',
        variables: [
          Variable<String>(buddyId),
          Variable<String>(agency),
          Variable<String>(level),
        ],
      ).get();
      if (existing.isNotEmpty) {
        // Same fact already recorded as a certification. Backfill the card
        // number when the cert lacks one -- the common "entered both halves"
        // case -- otherwise leave the richer cert row alone.
        final target = existing.first;
        final existingNumber = target.read<String?>('card_number');
        if ((existingNumber == null || existingNumber.isEmpty) &&
            cardNumber != null &&
            cardNumber.isNotEmpty) {
          await customStatement(
            'UPDATE certifications SET card_number = ? WHERE id = ?',
            [cardNumber, target.read<String>('id')],
          );
        }
        continue;
      }

      await customStatement(
        'INSERT INTO certifications '
        '(id, buddy_id, diver_id, name, agency, level, card_number, notes, '
        'created_at, updated_at) '
        'VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO NOTHING',
        [
          'buddyrolecert-${r.read<String>('id')}',
          buddyId,
          nameForRole[role]!,
          agency,
          level,
          cardNumber,
          r.read<String>('notes'),
          r.read<int>('created_at'),
          r.read<int>('updated_at'),
        ],
      );
    }
    await customStatement('DROP TABLE IF EXISTS buddy_roles');
  }

  /// Human-readable name for a migrated buddy cert: the level's display name
  /// when present, else the agency's.
  String _displayNameForMigratedCert(String? level, String agency) {
    if (level != null) {
      return CertificationLevel.values
          .firstWhere(
            (e) => e.name == level,
            orElse: () => CertificationLevel.other,
          )
          .displayName;
    }
    return CertificationAgency.values
        .firstWhere(
          (e) => e.name == agency,
          orElse: () => CertificationAgency.other,
        )
        .displayName;
  }

  Future<void> _assertBuddyFavoriteColumn() async {
    final cols = await customSelect("PRAGMA table_info('buddies')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('is_favorite')) {
      await customStatement(
        'ALTER TABLE buddies ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
    }
  }
}
