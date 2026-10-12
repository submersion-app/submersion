
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
  /// on this device is used. [asMemberId] overrides both (an accepted
  /// suggestion is attributed to its suggester).
  Future<void> stamp(
    String siteId,
    Set<String> fields, {
    String? actingDiverId,
    String? asMemberId,
  }) async {
    if (fields.isEmpty) return;
    final row = await (_db.select(
      _db.diveSites,
    )..where((t) => t.id.equals(siteId))).getSingleOrNull();
    final libraryId = row?.sharedLibraryId;
    if (libraryId == null) return;

    final memberId =
        asMemberId ?? await _resolveMember(libraryId, actingDiverId);
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

  /// The document fields a column patch writes.
  static Set<String> fieldsOfPatch(DiveSitesCompanion patch) => {
    if (patch.name.present) 'name',
    if (patch.description.present) 'description',
    if (patch.latitude.present) 'latitude',
    if (patch.longitude.present) 'longitude',
    if (patch.minDepth.present) 'minDepth',
    if (patch.maxDepth.present) 'maxDepth',
    if (patch.difficulty.present) 'difficulty',
    if (patch.waterType.present) 'waterType',
    if (patch.bodyOfWater.present) 'bodyOfWater',
    if (patch.city.present) 'city',
    if (patch.island.present) 'island',
    if (patch.country.present) 'country',
    if (patch.region.present) 'region',
    if (patch.rating.present) 'rating',
    if (patch.notes.present) 'notes',
    if (patch.hazards.present) 'hazards',
    if (patch.accessNotes.present) 'accessNotes',
    if (patch.mooringNumber.present) 'mooringNumber',
    if (patch.parkingInfo.present) 'parkingInfo',
    if (patch.altitude.present) 'altitude',
    if (patch.entryMethod.present) 'entryMethod',
    if (patch.exitMethod.present) 'exitMethod',
  };
}
