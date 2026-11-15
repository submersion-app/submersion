import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Keeps [diverId]'s built-in catalogue link and answers for the library
/// site [siteId] in their `library_site_notes` record, for personal sync
/// to carry to the profile's other devices.
///
/// A library site's own row never enters personal sync, and the link and
/// answers are one profile's view of the site, so they travel the way that
/// profile's private notes and rating do.
///
/// A profile with no record yet gets one. Where no profile has a record
/// for the site, it starts from the notes and rating on the row, which
/// nothing else holds: an empty record would be copied back over them.
/// Where another profile has one, the row shows that profile's private
/// notes, and the new record starts empty: they are not this profile's
/// to carry. The copy back onto the row (`applyLibrarySiteNotes`) passes
/// over such a record for the notes, so they stay on the row.
Future<void> putLibrarySiteCatalogue(
  AppDatabase db,
  SyncRepository sync, {
  required String diverId,
  required String siteId,
  required String? catalogueId,
  required String? catalogueAnswers,
}) async {
  final id = '$diverId:$siteId';
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.transaction(() async {
    final existing = await (db.select(
      db.librarySiteNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      final others =
          await (db.select(db.librarySiteNotes)
                ..where((t) => t.siteId.equals(siteId))
                ..limit(1))
              .get();
      final site = others.isNotEmpty
          ? null
          : await (db.select(
              db.diveSites,
            )..where((t) => t.id.equals(siteId))).getSingleOrNull();
      await db
          .into(db.librarySiteNotes)
          .insert(
            LibrarySiteNotesCompanion.insert(
              id: id,
              diverId: diverId,
              siteId: siteId,
              notes: Value(site?.notes ?? ''),
              rating: Value(site?.rating),
              catalogueId: Value(catalogueId),
              catalogueAnswers: Value(catalogueAnswers),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (db.update(
        db.librarySiteNotes,
      )..where((t) => t.id.equals(id))).write(
        LibrarySiteNotesCompanion(
          catalogueId: Value(catalogueId),
          catalogueAnswers: Value(catalogueAnswers),
          updatedAt: Value(now),
        ),
      );
    }
    await sync.markRecordPending(
      entityType: SharedLibraryStore.siteNotesEntity,
      recordId: id,
      localUpdatedAt: now,
    );
  });
  SyncEventBus.notifyLocalChange();
}
