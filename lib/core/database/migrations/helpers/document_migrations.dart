part of '../app_database_migrations.dart';

/// The documents store (v277, issue #2613).
extension DocumentMigrations on AppDatabase {
  /// Creates the documents tables and their indexes. Idempotent, and also
  /// the beforeOpen backstop, so it never copies data.
  Future<void> _assertDocumentsSchema() async {
    for (final parent in const [
      'divers',
      'dives',
      'dive_sites',
      'trips',
      'equipment',
      'courses',
      'certifications',
      'buddies',
      'dive_centers',
    ]) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(documents);
    await Migrator(this).createTable(documentPages);
    for (final column in const [
      'diver_id',
      'dive_id',
      'site_id',
      'trip_id',
      'equipment_id',
      'course_id',
      'certification_id',
      'buddy_id',
      'dive_center_id',
    ]) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_documents_$column '
        'ON documents($column)',
      );
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_document_pages_document '
      'ON document_pages(document_id, page_index)',
    );
  }

  /// v277 data step: copies insurance, medical clearance and certification
  /// card photos into documents. Runs ONLY in the rung: a beforeOpen run
  /// would resurrect a migrated document the diver later deleted. Ids are
  /// deterministic and the inserts are OR IGNORE, so a second device that
  /// upgrades the same library produces the same rows, and they merge.
  ///
  /// The source columns are left as they are; v294 clears the card photo
  /// columns this copy made redundant ([_clearCopiedCardPhotoColumns]).
  ///
  /// Each row takes its source row's created/updated time, identical on
  /// every device, rather than this device's migration time: a peer's edit
  /// or delete made after its own upgrade then applies here as a plain
  /// remote change, not as a conflict with an untouched local copy.
  Future<void> _migrateLegacyDocuments() async {
    if (!await _tableExists('documents')) return;
    final divers = await customSelect(
      'SELECT id, is_default, created_at, updated_at, '
      'insurance_provider, insurance_policy_number, '
      'insurance_expiry_date, insurance_emergency_phone, insurance_phone, '
      'medical_clearance_expiry_date FROM divers ORDER BY created_at, id',
    ).get();
    if (divers.isEmpty) return;

    String? present(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    for (final d in divers) {
      final diverId = d.read<String>('id');
      final created = d.read<int>('created_at');
      final updated = d.read<int>('updated_at');
      final provider = present(d.readNullable<String>('insurance_provider'));
      final policy = present(d.readNullable<String>('insurance_policy_number'));
      final expiry = d.readNullable<int>('insurance_expiry_date');
      final emergency = present(
        d.readNullable<String>('insurance_emergency_phone'),
      );
      final phone = present(d.readNullable<String>('insurance_phone'));
      if (provider != null ||
          policy != null ||
          expiry != null ||
          emergency != null ||
          phone != null) {
        await customStatement(
          'INSERT OR IGNORE INTO documents (id, diver_id, type, title, '
          'issuer, reference_number, expiry_date, emergency_phone, phone, '
          'is_primary, notes, created_at, updated_at) '
          "VALUES (?, ?, 'insurance', '', ?, ?, ?, ?, ?, 1, '', ?, ?)",
          [
            documentInsuranceId(diverId),
            diverId,
            provider,
            policy,
            expiry,
            emergency,
            phone,
            created,
            updated,
          ],
        );
      }
      final clearance = d.readNullable<int>('medical_clearance_expiry_date');
      if (clearance != null) {
        await customStatement(
          'INSERT OR IGNORE INTO documents (id, diver_id, type, title, '
          'expiry_date, is_primary, notes, created_at, updated_at) '
          "VALUES (?, ?, 'medicalClearance', '', ?, 0, '', ?, ?)",
          [
            documentMedicalClearanceId(diverId),
            diverId,
            clearance,
            created,
            updated,
          ],
        );
      }
    }

    // A legacy ownerless certification is filed under the default diver.
    final defaultDiverId = divers
        .firstWhere(
          (d) => (d.readNullable<int>('is_default') ?? 0) != 0,
          orElse: () => divers.first,
        )
        .read<String>('id');

    final certs = await customSelect(
      'SELECT c.id, c.diver_id, c.photo_front, c.photo_back, '
      'c.created_at, c.updated_at, '
      'b.diver_id AS buddy_diver_id FROM certifications c '
      'LEFT JOIN buddies b ON b.id = c.buddy_id '
      'WHERE c.photo_front IS NOT NULL OR c.photo_back IS NOT NULL',
    ).get();
    for (final c in certs) {
      final certId = c.read<String>('id');
      final diverId =
          c.readNullable<String>('diver_id') ??
          c.readNullable<String>('buddy_diver_id') ??
          defaultDiverId;
      final docId = documentCertificationCardId(certId);
      final created = c.read<int>('created_at');
      final updated = c.read<int>('updated_at');
      await customStatement(
        'INSERT OR IGNORE INTO documents (id, diver_id, certification_id, '
        'type, title, is_primary, notes, created_at, updated_at) '
        "VALUES (?, ?, ?, 'certificationCard', '', 0, '', ?, ?)",
        [docId, diverId, certId, created, updated],
      );
      var index = 0;
      for (final (side, column) in const [
        (DocumentPageSide.front, 'photo_front'),
        (DocumentPageSide.back, 'photo_back'),
      ]) {
        final bytes = c.readNullable<Uint8List>(column);
        if (bytes == null) continue;
        await customStatement(
          'INSERT OR IGNORE INTO document_pages (id, document_id, page_index, '
          'side, file_name, mime_type, size_bytes, bytes, created_at, '
          'updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            documentCardPageId(docId, side),
            docId,
            index++,
            side.name,
            '${side.name}.jpg',
            'image/jpeg',
            bytes.length,
            bytes,
            created,
            updated,
          ],
        );
      }
    }
    await _requestRebaseIfDocumentsMigrated();
  }

  /// v294 data step (issue #3502): clears certifications.photo_front and
  /// photo_back where the v277 copy is known to have run, which left every
  /// card photo stored twice and nearly doubled a backup. Nothing has read
  /// those columns since v277, and every peer that can apply this device's
  /// payloads is past the sync floor, so past v277 too.
  ///
  /// The copy ran for a certification when its card document exists, or
  /// when the deletion log shows the diver deleted that card since. Photos
  /// v277 never copied (it skips a library with no diver) are the only copy
  /// left, so they stay.
  ///
  /// Not a sync change: the columns no longer sync (deviceLocalSyncColumns),
  /// so the rows keep their clocks.
  Future<void> _clearCopiedCardPhotoColumns() async {
    if (!await _tableExists('certifications')) return;
    if (!await _tableExists('documents')) return;
    final withPhotos = await customSelect(
      'SELECT id FROM certifications '
      'WHERE photo_front IS NOT NULL OR photo_back IS NOT NULL',
    ).get();
    if (withPhotos.isEmpty) return;
    final cards = {
      for (final r in await customSelect(
        "SELECT id FROM documents WHERE type = 'certificationCard'",
      ).get())
        r.read<String>('id'),
      if (await _tableExists('deletion_log'))
        for (final r in await customSelect(
          'SELECT record_id FROM deletion_log '
          "WHERE entity_type = 'documents'",
        ).get())
          r.read<String>('record_id'),
    };
    final copied = [
      for (final r in withPhotos)
        if (cards.contains(documentCertificationCardId(r.read<String>('id'))))
          r.read<String>('id'),
    ];
    for (final chunk in copied.slices(500)) {
      await customStatement(
        'UPDATE certifications SET photo_front = NULL, photo_back = NULL '
        'WHERE id IN (${List.filled(chunk.length, '?').join(', ')})',
        chunk,
      );
    }
  }

  /// The migrated rows carry no clock, so no changeset ever selects them;
  /// a device that joins later adopts this device's base, which predates
  /// them. Ask the changeset writer for one fresh base (issue #2613).
  Future<void> _requestRebaseIfDocumentsMigrated() async {
    if (!await _tableExists('local_publish_states')) return;
    final migrated = await customSelect(
      'SELECT 1 FROM documents LIMIT 1',
    ).getSingleOrNull();
    if (migrated == null) return;
    await requestRebase(this);
  }
}
