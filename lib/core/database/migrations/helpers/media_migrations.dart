part of '../app_database_migrations.dart';

/// Media, media stores, subscriptions and connected accounts.
extension MediaMigrations on AppDatabase {
  /// Idempotent DDL for the v106 connector-suggestion columns (Lightroom
  /// auto-linking). Called from the v106 onUpgrade block and from the
  /// beforeOpen backstop so a parallel-branch schema-version collision
  /// cannot strand a database without them.
  Future<void> _assertConnectorSuggestionColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('pending_photo_suggestions')",
    ).get();
    // An empty PRAGMA result means the table itself is absent (only
    // possible in minimal test fixtures); skip the ALTERs rather than fail.
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('connector_account_id')) {
      await customStatement(
        'ALTER TABLE pending_photo_suggestions '
        'ADD COLUMN connector_account_id TEXT',
      );
    }
    if (!names.contains('remote_asset_id')) {
      await customStatement(
        'ALTER TABLE pending_photo_suggestions '
        'ADD COLUMN remote_asset_id TEXT',
      );
    }
  }

  /// v107: connected accounts roster + sync account selection. Idempotent;
  /// also run from beforeOpen as a parallel-branch collision backstop.
  Future<void> _assertConnectedAccountsSchema() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS connected_accounts ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'kind TEXT NOT NULL, '
      'label TEXT NOT NULL, '
      'account_identifier TEXT, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'hlc TEXT)',
    );
    final metaCols = await customSelect(
      "PRAGMA table_info('sync_metadata')",
    ).get();
    if (metaCols.isNotEmpty &&
        !metaCols.any((c) => c.read<String>('name') == 'sync_account_id')) {
      await customStatement(
        'ALTER TABLE sync_metadata ADD COLUMN sync_account_id TEXT',
      );
    }
  }

  /// v108: HLC on media_subscriptions so the table can sync. Idempotent;
  /// also run from beforeOpen as a parallel-branch collision backstop.
  Future<void> _assertMediaSubscriptionsHlc() async {
    final cols = await customSelect(
      "PRAGMA table_info('media_subscriptions')",
    ).get();
    // An empty PRAGMA result means the table itself is absent (only
    // possible in minimal test fixtures); skip the ALTER rather than fail.
    if (cols.isEmpty) return;
    if (!cols.any((c) => c.read<String>('name') == 'hlc')) {
      await customStatement(
        'ALTER TABLE media_subscriptions ADD COLUMN hlc TEXT',
      );
    }
  }

  /// v143: Media section Phase 5 tables. createTable is CREATE TABLE IF NOT
  /// EXISTS, so this is safe to call from both onUpgrade and the beforeOpen
  /// backstop (parallel-branch collision self-heal).
  Future<void> _assertMediaPhase5Schema() async {
    await Migrator(this).createTable(mediaRepairLog);
    await Migrator(this).createTable(mediaSmartAlbums);
  }

  /// v140: media.retain_in_library (Media section Phase 1). Idempotent; safe
  /// to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertMediaRetainInLibraryColumn() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('retain_in_library')) {
      await customStatement(
        'ALTER TABLE media ADD COLUMN retain_in_library '
        'INTEGER NOT NULL DEFAULT 0 CHECK (retain_in_library IN (0, 1))',
      );
    }
  }

  /// v164: media.manual_elapsed_seconds (issue #1090). Idempotent; safe to
  /// call from both onUpgrade and the beforeOpen backstop. Nullable with no
  /// default, so every pre-existing row reads back as "position from
  /// taken_at".
  Future<void> _assertMediaManualElapsedColumn() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('manual_elapsed_seconds')) {
      await customStatement(
        'ALTER TABLE media ADD COLUMN manual_elapsed_seconds INTEGER',
      );
    }
  }

  /// v130: media_enrichment.hlc column. Self-guarding when the table is absent
  /// (partial-schema migration fixtures) and PRAGMA-guarded so it is safe to
  /// call from both onUpgrade and the beforeOpen backstop (parallel-branch
  /// collision self-heal).
  Future<void> _assertMediaEnrichmentHlcColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('media_enrichment')",
    ).get();
    final hasColumn = cols.any((c) => c.read<String>('name') == 'hlc');
    if (cols.isNotEmpty && !hasColumn) {
      await customStatement('ALTER TABLE media_enrichment ADD COLUMN hlc TEXT');
    }
  }

  /// Idempotent DDL for the v103 media store objects. Called from the v103
  /// onUpgrade block and from the beforeOpen backstop so a parallel-branch
  /// schema-version collision cannot strand a database without them.
  Future<void> _assertMediaStoreSchema() async {
    // An empty PRAGMA result means the media table itself is absent (only
    // possible in minimal test fixtures); skip the ALTERs rather than fail.
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isNotEmpty) {
      final names = cols.map((c) => c.read<String>('name')).toSet();
      Future<void> add(String name, String type) async {
        if (!names.contains(name)) {
          await customStatement('ALTER TABLE media ADD COLUMN $name $type');
        }
      }

      await add('content_hash', 'TEXT');
      await add('content_size_bytes', 'INTEGER');
      await add('remote_uploaded_at', 'INTEGER');
      await add('remote_thumb_uploaded_at', 'INTEGER');
    }
    await customStatement('''
      CREATE TABLE IF NOT EXISTS media_stores (
        id TEXT NOT NULL PRIMARY KEY,
        provider_type TEXT NOT NULL,
        display_hint TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
  }

  /// Idempotent DDL for the v136 media_stores.last_sweep_at column
  /// (fleet-wide Verify Library timestamp). Called from the v136 onUpgrade
  /// step and the beforeOpen backstop, matching the _assertMediaStoreSchema
  /// pattern so a schema-version collision cannot strand a database
  /// without it. Self-guarding when the table is absent (minimal
  /// fixtures) - the v103 backstop creates it first in real databases.
  Future<void> _assertMediaStoresLastSweepColumn() async {
    final cols = await customSelect("PRAGMA table_info('media_stores')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('last_sweep_at')) {
      await customStatement(
        'ALTER TABLE media_stores ADD COLUMN last_sweep_at INTEGER',
      );
    }
  }

  /// Idempotent DDL for the v189 media.equipment_id column plus its lookup
  /// index (issue #1517): the link that makes an invoice or receipt an
  /// attachment of a piece of gear. Self-guards on the media table existing,
  /// so a partial migration-test fixture passes through untouched. Same
  /// dual-call contract (onUpgrade + beforeOpen backstop) as the other
  /// column-assert helpers.
  ///
  /// No REFERENCES clause: SQLite cannot add a foreign key with ALTER TABLE,
  /// so a migrated database enforces the equipment link at the repository
  /// layer only -- exactly what media.site_id has always done for the rows
  /// that predate it.
  Future<void> _assertMediaEquipmentIdColumn() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('equipment_id')) {
      await customStatement('ALTER TABLE media ADD COLUMN equipment_id TEXT');
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_equipment_id '
      'ON media(equipment_id)',
    );
  }

  Future<void> _assertMediaFactClockColumns() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('upload_facts_hlc')) {
      await customStatement(
        'ALTER TABLE media ADD COLUMN upload_facts_hlc TEXT',
      );
    }
    if (!names.contains('verify_facts_hlc')) {
      await customStatement(
        'ALTER TABLE media ADD COLUMN verify_facts_hlc TEXT',
      );
    }
  }

  Future<void> _assertMediaCloudAssetIdColumn() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('cloud_asset_id')) {
      await customStatement('ALTER TABLE media ADD COLUMN cloud_asset_id TEXT');
    }
  }

  /// v224: existing facts were last written under the row clock, so that is
  /// their clock. Rows already stamped (a re-run) are left alone. Guarded
  /// like the backstops: a partially built database (a migration fixture, or
  /// one caught mid-ladder) may lack the table or its row clock.
  Future<void> _backfillMediaFactClocks() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('hlc')) return;
    for (final column in const ['upload_facts_hlc', 'verify_facts_hlc']) {
      if (!names.contains(column)) continue;
      await customStatement(
        'UPDATE media SET $column = hlc WHERE $column IS NULL',
      );
    }
  }

  /// The v195 media_species.hlc column (issue #1638): the tag's own clock,
  /// which is what puts it in an incremental changeset. PRAGMA-guarded so a
  /// healthy database no-ops and a partial schema does not throw. Called
  /// from the v195 onUpgrade step and the beforeOpen backstop, matching the
  /// other additive column helpers.
  Future<void> _assertMediaSpeciesHlcColumn() async {
    final cols = await customSelect("PRAGMA table_info('media_species')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('hlc')) return;
    await customStatement('ALTER TABLE media_species ADD COLUMN hlc TEXT');
  }

  /// Idempotent DDL for the v133 compressed-rendition columns. Called from the
  /// v133 onUpgrade step and the beforeOpen backstop, matching the
  /// _assertMediaStoreSchema pattern so a schema-version collision cannot
  /// strand a database without them.
  Future<void> _assertMediaCompressedRenditionColumns() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    Future<void> add(String name, String type) async {
      if (!names.contains(name)) {
        await customStatement('ALTER TABLE media ADD COLUMN $name $type');
      }
    }

    await add('compressed_level', 'TEXT');
    await add('compressed_size_bytes', 'INTEGER');
    await add('remote_compressed_uploaded_at', 'INTEGER');
  }
}
