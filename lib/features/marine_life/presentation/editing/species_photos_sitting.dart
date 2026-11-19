import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_card_ids.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The held change of the photos tagged with the species on its page
/// (issue #4527, phase 3).
const String speciesTagsKey = 'species.tags';

const String _itemsKey = 'species.tags.items';

/// The photos the sitting will tag with its species at Save, in the order
/// they were chosen.
List<MediaItem> heldSpeciesTags(EditSession<Species> session) =>
    session.isDisposed
    ? const []
    : session.recall<List<MediaItem>>(_itemsKey) ?? const [];

/// Holds [items] to be tagged with the sitting's species at Save, with
/// those already held: one change of the Photos card. Each is tagged as the
/// tag picker tags it ([SpeciesTaggingService.tagPhoto]), which also logs
/// the sighting a dive photo needs, inside the sitting's transaction; one
/// that cannot be tagged fails the whole Save.
void holdSpeciesTags(
  EditSession<Species> session,
  Iterable<MediaItem> items,
  SpeciesTaggingService tagging,
) {
  if (session.isDisposed || session.isFrozen) return;
  final held = heldSpeciesTags(session);
  final ids = {for (final m in held) m.id};
  _hold(session, [
    ...held,
    for (final m in items)
      if (ids.add(m.id)) m,
  ], tagging);
}

/// Takes [mediaId] out of the photos to tag; none left is no change.
void releaseSpeciesTag(EditSession<Species> session, String mediaId) {
  if (session.isDisposed || session.isFrozen) return;
  final tagging = session.recall<SpeciesTaggingService>('$_itemsKey.service');
  if (tagging == null) return;
  _hold(session, [
    for (final m in heldSpeciesTags(session))
      if (m.id != mediaId) m,
  ], tagging);
}

void _hold(
  EditSession<Species> session,
  List<MediaItem> items,
  SpeciesTaggingService tagging,
) {
  session
    ..remember(_itemsKey, List<MediaItem>.unmodifiable(items))
    ..remember('$_itemsKey.service', tagging);
  if (items.isEmpty) {
    session.releaseWrite(speciesTagsKey);
    return;
  }
  final speciesId = session.stored.id;
  final ids = [for (final m in items) m.id];
  session.holdChange(
    speciesTagsKey,
    cardId: SpeciesCardId.photos.name,
    write: () async {
      for (final id in ids) {
        await tagging.tagPhoto(mediaId: id, speciesId: speciesId);
      }
    },
  );
}

/// Writes prepared photos' rows, as [MediaImportService.writePrepared] does.
typedef SpeciesImportWriter =
    Future<List<MediaItem>> Function(List<PreparedMedia> prepared);

/// The writer a species page's held import uses; a seam for tests.
final speciesImportWriterProvider = Provider<SpeciesImportWriter>(
  (ref) => ref.watch(mediaImportServiceProvider).writePrepared,
);

/// The held change of the photos added on the species page.
const String speciesImportsKey = 'species.imports';

const String _importsKey = 'species.imports.held';
const String _importsToolsKey = 'species.imports.tools';
const String _writtenKey = 'species.imports.written';

/// The photos the sitting will add at Save, prepared for their dive or
/// site, in the order they were chosen.
List<PreparedMedia> heldSpeciesImports(EditSession<Species> session) =>
    session.isDisposed
    ? const []
    : session.recall<List<PreparedMedia>>(_importsKey) ?? const [];

/// The rows the sitting's last write of its added photos created, for what
/// follows the commit (their uploads).
List<String> speciesImportsWritten(EditSession<Species> session) =>
    session.isDisposed
    ? const []
    : session.recall<List<String>>(_writtenKey) ?? const [];

/// Holds [prepared] photos to be added at Save, with those already held:
/// one change of the Photos card. At Save their rows are written by
/// [write] and each is tagged with the species ([SpeciesTaggingService
/// .tagPhoto]), inside the sitting's transaction, so a failure leaves no
/// row and no tag.
void holdSpeciesImports(
  EditSession<Species> session,
  Iterable<PreparedMedia> prepared, {
  required SpeciesImportWriter write,
  required SpeciesTaggingService tagging,
}) {
  if (session.isDisposed || session.isFrozen) return;
  session.remember(_importsToolsKey, (write: write, tagging: tagging));
  final held = heldSpeciesImports(session);
  final seen = {for (final p in held) _sourceOf(p.item)};
  _holdImports(session, [
    ...held,
    // A photo chosen again for the same dive or site is held once: each
    // prepare gives it a fresh row id, and only stored links are skipped.
    for (final p in prepared)
      if (seen.add(_sourceOf(p.item))) p,
  ]);
}

/// The photo [item] is of, and the dive or site it goes to.
(String?, String?, String?) _sourceOf(MediaItem item) => (
  item.platformAssetId ?? item.filePath ?? item.url ?? item.id,
  item.diveId,
  item.siteId,
);

/// Takes the prepared photo [mediaId] out of the photos to add; none left
/// is no change.
void releaseSpeciesImport(EditSession<Species> session, String mediaId) {
  if (session.isDisposed || session.isFrozen) return;
  _holdImports(session, [
    for (final p in heldSpeciesImports(session))
      if (p.item.id != mediaId) p,
  ]);
}

void _holdImports(EditSession<Species> session, List<PreparedMedia> held) {
  final tools = session
      .recall<({SpeciesImportWriter write, SpeciesTaggingService tagging})>(
        _importsToolsKey,
      );
  session.remember(_importsKey, List<PreparedMedia>.unmodifiable(held));
  if (held.isEmpty || tools == null) {
    session.releaseWrite(speciesImportsKey);
    return;
  }
  final speciesId = session.stored.id;
  session.holdChange(
    speciesImportsKey,
    cardId: SpeciesCardId.photos.name,
    write: () async {
      final rows = await tools.write(held);
      for (final row in rows) {
        await tools.tagging.tagPhoto(mediaId: row.id, speciesId: speciesId);
      }
      session.remember(_writtenKey, [for (final row in rows) row.id]);
    },
  );
}
