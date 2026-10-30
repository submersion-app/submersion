import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_bridge.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// Reader suggestions and owner review (issue #2567). A proposal holds only
/// the fields that differ from the stored site; the library sync carries
/// it to the folder and brings an owner's inbox back.
class SuggestionService {
  SuggestionService({
    SharedLibraryStore? store,
    SiteDocumentBridge? bridge,
    LibraryEditStamper? stamper,
    required Future<SharedLibraryTransport> Function(SharedLibrary library)
    transportFor,
  }) : _store = store ?? SharedLibraryStore(),
       _bridge = bridge ?? SiteDocumentBridge(),
       _stamper = stamper ?? LibraryEditStamper(),
       _transportFor = transportFor;

  final SharedLibraryStore _store;
  final SiteDocumentBridge _bridge;
  final LibraryEditStamper _stamper;
  final Future<SharedLibraryTransport> Function(SharedLibrary) _transportFor;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SuggestionService);

  /// A reader's proposal: the scalar fields of [proposed] that differ from
  /// the stored site, plus [childFields] (changed child lists in document
  /// form) and the note. Returns null when nothing changed.
  Future<SharedSiteSuggestion?> propose({
    required domain.DiveSite proposed,
    required String diverId,
    String note = '',
    Map<String, Object?> childFields = const {},
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sharedLibrary);
    final stored = await SiteRepository().getSiteById(proposed.id);
    final libraryId = stored?.sharedLibraryId;
    if (stored == null || libraryId == null) {
      throw StateError('site ${proposed.id} is not in a library');
    }
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    if (membership == null) {
      throw StateError('profile $diverId is not a member of $libraryId');
    }
    // An editor or owner edits the site; a suggestion is a reader's way in.
    final library = await _store.getLibrary(libraryId);
    final role = library == null
        ? SharedLibraryRole.reader
        : effectiveRole(
            listed: library.roles.roleOf(membership.memberId),
            readOnlyDetected: library.writesHeld,
          );
    if (!canSuggestOnLibrarySite(role)) {
      throw StateError('only a reader suggests changes in $libraryId');
    }
    final fields = <String, Object?>{
      for (final f in LibraryEditStamper.changedFields(stored, proposed))
        f: SiteDocumentBridge.fieldValue(proposed, f),
      for (final e in childFields.entries)
        if (SiteDocument.listFields.contains(e.key)) e.key: e.value,
    };
    if (fields.isEmpty) return null;
    final suggestion = SharedSiteSuggestion(
      id: _uuid.v4(),
      libraryId: libraryId,
      siteId: stored.id,
      memberId: membership.memberId,
      memberName: membership.displayName,
      note: note.trim(),
      fields: fields,
      createdAt: DateTime.now().toUtc(),
      direction: SharedSiteSuggestion.outgoing,
    );
    await _store.putSuggestion(suggestion);
    SyncEventBus.notifyLocalChange();
    return suggestion;
  }

  /// Drops an outgoing suggestion. One already uploaded is deleted from
  /// the folder too when the storage allows.
  Future<void> withdraw(String suggestionId) async {
    final s = await _store.getSuggestion(suggestionId);
    if (s == null) return;
    if (s.status == SharedSiteSuggestion.uploaded) {
      await _finish(s, SharedSiteSuggestion.withdrawn);
      return;
    }
    await _store.deleteSuggestion(suggestionId);
  }

  /// Owner: applies the fields as the owner's own edit (signed by the
  /// owner, the only key here), dirties the site, then removes the
  /// suggestion here and in the folder. A suggestion whose site is gone is
  /// dismissed instead.
  Future<void> accept(String suggestionId, {required String diverId}) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sharedLibrary);
    final s = await _store.getSuggestion(suggestionId);
    if (s == null) return;
    await _requireOwner(s.libraryId, diverId);
    final site = await SiteRepository().getSiteById(s.siteId);
    if (site == null || site.sharedLibraryId != s.libraryId) {
      _log.info('Suggestion $suggestionId names a site that is gone');
      await dismiss(suggestionId, diverId: diverId);
      return;
    }
    // Only shared document fields: a suggestion from an older or altered
    // build may carry an owner's private notes or rating, never applied.
    final fields = {
      for (final e in s.fields.entries)
        if (SiteDocument.fieldNames.contains(e.key)) e.key: e.value,
    };
    if (fields.isNotEmpty) {
      await _bridge.apply(
        SiteDocument(id: s.siteId, fields: fields),
        libraryId: s.libraryId,
        vocabularyDiverId: diverId,
        fields: fields.keys.toSet(),
      );
      await _stamper.stamp(
        s.siteId,
        fields.keys.toSet(),
        actingDiverId: diverId,
      );
    }
    await _finish(s, SharedSiteSuggestion.resolved);
    SyncEventBus.notifyLocalChange();
  }

  /// Owner: drops the suggestion here and in the folder.
  Future<void> dismiss(String suggestionId, {required String diverId}) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sharedLibrary);
    final s = await _store.getSuggestion(suggestionId);
    if (s == null) return;
    await _requireOwner(s.libraryId, diverId);
    await _finish(s, SharedSiteSuggestion.resolved);
  }

  /// The service enforces the owner role itself; the UI only hides the
  /// inbox from everyone else.
  Future<void> _requireOwner(String libraryId, String diverId) async {
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    final library = await _store.getLibrary(libraryId);
    if (membership == null ||
        library == null ||
        library.roles.roleOf(membership.memberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner reviews suggestions');
    }
  }

  /// For the review sheet: field name to (stored value, proposed value).
  Future<Map<String, (Object?, Object?)>> diff(SharedSiteSuggestion s) async {
    final site = await SiteRepository().getSiteById(s.siteId);
    if (site == null) {
      return {for (final e in s.fields.entries) e.key: (null, e.value)};
    }
    Map<String, Object?> current = const {};
    if (s.fields.keys.any(SiteDocument.listFields.contains)) {
      final state =
          await _store.getSiteState(s.siteId) ??
          SharedSiteState(siteId: s.siteId, libraryId: s.libraryId);
      current = (await _bridge.build(s.siteId, state)).fields;
    }
    return {
      for (final e in s.fields.entries)
        e.key: (
          SiteDocument.listFields.contains(e.key)
              ? current[e.key]
              : SiteDocumentBridge.fieldValue(site, e.key),
          e.value,
        ),
    };
  }

  /// Removes [s] here and in the folder. When the folder's copy cannot be
  /// deleted now (offline, say), the row stays under [marker], out of every
  /// list, so the next sync neither re-imports it nor loses the delete.
  Future<void> _finish(SharedSiteSuggestion s, String marker) async {
    if (await _deleteRemote(s)) {
      await _store.deleteSuggestion(s.id);
    } else {
      await _store.putSuggestion(s.copyWith(status: marker));
    }
  }

  /// True when the folder no longer holds [s], or this device cannot reach
  /// the library at all (nothing would ever retry).
  Future<bool> _deleteRemote(SharedSiteSuggestion s) async {
    final library = await _store.getLibrary(s.libraryId);
    if (library == null) return true;
    try {
      final t = await _transportFor(library);
      await t.deleteSuggestion(s.fileId);
      return true;
    } on CloudStorageException catch (e) {
      _log.warning('Could not delete suggestion ${s.id} remotely: $e');
      return false;
    } on StateError catch (e) {
      _log.warning('Could not reach the library for ${s.id}: $e');
      return true;
    }
  }
}
