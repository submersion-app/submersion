import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/member_clock.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_bridge.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;

/// Records which document fields a local write changed on a library site
/// (issue #2567): each gets a fresh clock under the editing member and the
/// site's state turns dirty, so the next library sync uploads it. A
/// personal site is never touched.
class LibraryEditStamper {
  LibraryEditStamper({SharedLibraryStore? store})
    : _store = store ?? SharedLibraryStore();

  final SharedLibraryStore _store;
  AppDatabase get _db => DatabaseService.instance.database;

  /// The member recorded when no membership can be resolved: the clock
  /// still orders the edit, only the name is lost.
  static const unknownMember = 'unknown';

  /// Stamps [fields] on [siteId]. [actingDiverId] picks the member through
  /// that profile's membership; without it, the library's sole membership
  /// on this device is used.
  Future<void> stamp(
    String siteId,
    Set<String> fields, {
    String? actingDiverId,
  }) async {
    if (fields.isEmpty) return;
    final row = await (_db.select(
      _db.diveSites,
    )..where((t) => t.id.equals(siteId))).getSingleOrNull();
    final libraryId = row?.sharedLibraryId;
    if (libraryId == null) return;

    final memberId = await _resolveMember(libraryId, actingDiverId);
    final existing =
        await _store.getSiteState(siteId) ??
        SharedSiteState(siteId: siteId, libraryId: libraryId);
    final clock = MemberClock(memberId);
    for (final c in existing.clocks.values) {
      clock.receive(c.hlc);
    }
    final clocks = Map<String, FieldClock>.from(existing.clocks);
    for (final field in fields) {
      clocks[field] = FieldClock(hlc: clock.next(), memberId: memberId);
    }
    await _store.putSiteState(
      existing.copyWith(
        clocks: clocks,
        dirty: true,
        lastEditorMemberId: memberId,
        lastEditedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Keeps the private notes and rating of [siteId] for the profile
  /// [actingDiverId] (or the library's sole local profile), to reach its
  /// other devices through personal sync.
  Future<void> keepPrivate(
    String siteId, {
    required String notes,
    required double? rating,
    String? actingDiverId,
  }) async {
    final row = await (_db.select(
      _db.diveSites,
    )..where((t) => t.id.equals(siteId))).getSingleOrNull();
    final libraryId = row?.sharedLibraryId;
    if (libraryId == null) return;
    var diverId = actingDiverId;
    if (diverId == null) {
      final all = await _store.membershipsForLibrary(libraryId);
      if (all.length != 1) return;
      diverId = all.single.diverId;
    }
    await _store.putSiteNotes(
      diverId: diverId,
      siteId: siteId,
      notes: notes,
      rating: rating,
    );
  }

  /// Whether a write to [siteId] may go ahead here: always for a personal
  /// site; for a library site, when the profile [actingDiverId] is a member
  /// that may edit it. Naming no profile, every local member must be able
  /// to: where one only reads, a write nobody can attribute could be theirs.
  /// A write nobody here may make is never uploaded, and only sets this
  /// device apart.
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async {
    final row = await (_db.select(
      _db.diveSites,
    )..where((t) => t.id.equals(siteId))).getSingleOrNull();
    final libraryId = row?.sharedLibraryId;
    if (libraryId == null) return true;
    final library = await _store.getLibrary(libraryId);
    // Not connected here: no roles to go by, nothing to upload to.
    if (library == null) return true;
    final members = [
      for (final m in await _store.membershipsForLibrary(libraryId))
        if (actingDiverId == null || m.diverId == actingDiverId) m,
    ];
    bool edits(SharedLibraryMembership m) => canEditLibrarySite(
      effectiveRole(
        listed: library.roles.roleOf(m.memberId),
        readOnlyDetected: library.writesHeld,
      ),
    );
    return members.isNotEmpty &&
        (actingDiverId == null ? members.every(edits) : members.any(edits));
  }

  Future<String> _resolveMember(String libraryId, String? diverId) async {
    if (diverId != null) {
      final own = await _store.membership(
        diverId: diverId,
        libraryId: libraryId,
      );
      if (own != null) return own.memberId;
    }
    final all = await _store.membershipsForLibrary(libraryId);
    if (all.length == 1) return all.single.memberId;
    return unknownMember;
  }

  /// The scalar document fields whose value differs between [before] and
  /// [after]. Child lists are stamped by the repositories that write them.
  static Set<String> changedFields(
    domain.DiveSite before,
    domain.DiveSite after,
  ) => {
    for (final f in SiteDocument.fieldNames)
      if (!SiteDocument.listFields.contains(f) &&
          SiteDocumentBridge.fieldValue(before, f) !=
              SiteDocumentBridge.fieldValue(after, f))
        f,
  };
}
