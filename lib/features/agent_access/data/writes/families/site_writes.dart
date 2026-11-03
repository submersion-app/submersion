import 'package:drift/drift.dart' show QueryRow, Variable;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;

/// What a library reader may change: never in the library, kept per profile.
const _privateKeys = {'notes', 'rating'};

class SiteWrites extends WritableEntry {
  SiteWrites(this._r, {LibraryEditStamper? stamper})
    : _stamper = stamper ?? LibraryEditStamper();

  final RecordRepositories _r;
  final LibraryEditStamper _stamper;

  @override
  String get name => 'sites';

  @override
  String get table => 'dive_sites';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200),
    'description': const FieldCodec.text(allowBlank: true),
    'latitude': const FieldCodec.number(min: -90, max: 90, nullable: true),
    'longitude': const FieldCodec.number(min: -180, max: 180, nullable: true),
    'min_depth_m': const FieldCodec.number(min: 0, max: 350, nullable: true),
    'max_depth_m': const FieldCodec.number(min: 0, max: 350, nullable: true),
    'difficulty': FieldCodec.enumName(SiteDifficulty.values, nullable: true),
    'water_type': FieldCodec.enumName(WaterType.values, nullable: true),
    'country': const FieldCodec.text(maxLength: 200, nullable: true),
    'region': const FieldCodec.text(maxLength: 200, nullable: true),
    'city': const FieldCodec.text(maxLength: 200, nullable: true),
    'island': const FieldCodec.text(maxLength: 200, nullable: true),
    'body_of_water': const FieldCodec.text(maxLength: 200, nullable: true),
    'rating': const FieldCodec.number(min: 0, max: 5, nullable: true),
    'notes': const FieldCodec.text(allowBlank: true),
    'hazards': const FieldCodec.text(nullable: true),
    'access_notes': const FieldCodec.text(nullable: true),
    'mooring_number': const FieldCodec.text(maxLength: 200, nullable: true),
    'parking_info': const FieldCodec.text(nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  final Map<String, RelationSpec> relations = const {
    'tags': RelationSpec(refEntity: 'tags'),
    'expected_species': RelationSpec(refEntity: 'species'),
  };

  /// The link table and column of each relation.
  static const _links = {
    'tags': ('site_tags', 'tag_id'),
    'expected_species': ('site_species', 'species_id'),
  };

  @override
  Future<Set<String>> currentRelation(String id, String relation) async {
    final (table, column) = _links[relation]!;
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT $column AS linked FROM $table WHERE site_id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return {for (final row in rows) row.read<String>('linked')};
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final media = await _r.media.partitionMediaForSiteDeletion([id]);
    final documents = await countDocuments(await deletedDocumentOwners(id));
    // A photo of a dive the set also deletes is that dive's to count.
    final dives = [...?alongside['dives']];
    final divesOwn = dives.isEmpty
        ? 0
        : await countRows(
            'media',
            '"site_id" = ?1 AND "dive_id" IN (${marksFrom2(dives.length)})',
            id,
            dives,
          );
    final kept = media.unlinkIds.length - divesOwn;
    return DeleteReach(
      // A dive the set deletes goes, rather than losing its site.
      linkedDives: await countDivesByOwner(
        'SELECT diver_id AS owner, COUNT(*) AS n FROM dives WHERE site_id = ?1 '
        'AND id NOT IN (${marksFrom2(dives.length)}) GROUP BY diver_id',
        id,
        dives,
      ),
      records: {
        if (documents > 0) 'documents': documents,
        if (media.doomed.isNotEmpty) 'media': media.doomed.length,
      },
      parts: await countCascaded('dive_sites', id),
      unlinked: {
        ...await countUnlinked(
          'dive_sites',
          id,
          except: const {'dives', 'documents', 'media'},
        ),
        if (kept > 0) 'media': kept,
      },
    );
  }

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.site, id),
  ];

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final point = _pointBlock(check) ?? await _siteTagBlock(check);
    if (point != null) return point;
    if (check.kind == ChangeKind.create) return null;
    final library = check.document?['shared_library_id'] != null;
    if (!library) return null;
    // A local delete would drop the row for every profile here and leave the
    // library holding it. The app removes these through the library itself.
    if (check.kind == ChangeKind.delete) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'This site belongs to a shared library. Remove it from the library '
        'in the app.',
      );
    }
    final mayEdit = await _stamper.mayEdit(
      check.id!,
      actingDiverId: check.ownerId,
    );
    if (mayEdit) return null;
    // updateSite would quietly keep the library's values and report success,
    // and the link writes would quietly skip, so the refusal has to happen
    // here.
    if (check.kind == ChangeKind.update &&
        check.relations.values.every((delta) => delta.isEmpty) &&
        check.values.keys.every(_privateKeys.contains)) {
      return null;
    }
    return const PlanBlock(
      BlockReason.notPermitted,
      'This profile may only change its own notes and rating on this '
      'shared library site.',
    );
  }

  /// A block for a tag the site editor would not offer: one not used for
  /// sites.
  Future<PlanBlock?> _siteTagBlock(WriteCheck check) async {
    final added = check.relations['tags']?.add ?? const <String>{};
    if (added.isEmpty) return null;
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT id, applies_to_sites FROM tags WHERE id IN '
          '(${List.filled(added.length, '?').join(', ')})',
          variables: [for (final id in added) Variable.withString(id)],
        )
        .get();
    // A change earlier in the set to a tag's scopes is what the link meets.
    bool forSites(QueryRow row) => switch (check.soFar.values[(
      'tags',
      row.read<String>('id'),
    )]?['scopes']) {
      final String scopes => scopes.split(',').contains('sites'),
      _ => row.read<bool>('applies_to_sites'),
    };
    final other = [
      for (final row in rows)
        if (!forSites(row)) row.read<String>('id'),
    ];
    if (other.isEmpty) return null;
    return PlanBlock(
      BlockReason.invalidValue,
      'tags: ${other.join(', ')} is not used for sites. Add sites to its '
      'scopes first.',
    );
  }

  /// A site has a position or none, never half of one.
  PlanBlock? _pointBlock(WriteCheck check) {
    final values = check.values;
    if (!values.containsKey('latitude') && !values.containsKey('longitude')) {
      return null;
    }
    Object? pick(String key) =>
        values.containsKey(key) ? values[key] : check.document?[key];
    if ((pick('latitude') == null) == (pick('longitude') == null)) return null;
    return const PlanBlock(
      BlockReason.invalidValue,
      'latitude and longitude are set or cleared together.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final blank = DiveSite(
      id: '',
      diverId: diverId,
      name: values['name']! as String,
    );
    final site = await _r.sites.createSite(_applied(blank, values));
    return site.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (update.values.isNotEmpty) {
      final site = await _r.sites.getSiteById(id);
      if (site == null) {
        throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Site $id no longer exists.',
          details: {'id': id},
        );
      }
      await _r.sites.updateSite(
        _applied(site, update.values),
        actingDiverId: ownerId,
      );
    }
    // Tags as the site editor saves them, the whole list at once.
    if (update.relations['tags'] case final tags? when !tags.isEmpty) {
      final now = await currentRelation(id, 'tags');
      await _r.siteClassification.replaceTags(id, [
        ...now.difference(tags.remove),
        ...tags.add,
      ], actingDiverId: ownerId);
    }
    if (update.relations['expected_species'] case final species?) {
      for (final speciesId in species.add) {
        await _r.species.addExpectedSpecies(
          siteId: id,
          speciesId: speciesId,
          actingDiverId: ownerId,
        );
      }
      for (final speciesId in species.remove) {
        await _r.species.removeExpectedSpecies(
          id,
          speciesId,
          actingDiverId: ownerId,
        );
      }
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final deleted = await _r.sites.deleteSite(
      id,
      // A revert restores the rows, and its media needs the blobs still there.
      holdRemoteMedia: true,
      actingDiverId: ownerId,
    );
    if (deleted) return;
    throw AgentToolException(
      AgentToolErrorCode.writeRefused,
      'Another profile owns site $id, so it cannot be deleted from here.',
      details: {'id': id},
    );
  }

  DiveSite _applied(DiveSite site, Map<String, Object?> v) {
    bool clears(String key) => v.containsKey(key) && v[key] == null;
    T? value<T>(String key) => v[key] as T?;
    SiteDifficulty? difficulty() => v['difficulty'] == null
        ? null
        : SiteDifficulty.values.byName(v['difficulty']! as String);
    WaterType? water() => v['water_type'] == null
        ? null
        : WaterType.values.byName(v['water_type']! as String);
    final latitude = value<double>('latitude') ?? site.location?.latitude;
    final longitude = value<double>('longitude') ?? site.location?.longitude;
    return site.copyWith(
      name: value<String>('name'),
      description: value<String>('description'),
      location: latitude != null && longitude != null
          ? GeoPoint(latitude, longitude)
          : null,
      clearLocation: clears('latitude') || clears('longitude'),
      minDepth: value<double>('min_depth_m'),
      clearMinDepth: clears('min_depth_m'),
      maxDepth: value<double>('max_depth_m'),
      clearMaxDepth: clears('max_depth_m'),
      difficulty: difficulty(),
      clearDifficulty: clears('difficulty'),
      waterType: water(),
      clearWaterType: clears('water_type'),
      country: value<String>('country'),
      clearCountry: clears('country'),
      region: value<String>('region'),
      clearRegion: clears('region'),
      city: value<String>('city'),
      clearCity: clears('city'),
      island: value<String>('island'),
      clearIsland: clears('island'),
      bodyOfWater: value<String>('body_of_water'),
      clearBodyOfWater: clears('body_of_water'),
      rating: value<double>('rating'),
      clearRating: clears('rating'),
      notes: value<String>('notes'),
      hazards: value<String>('hazards'),
      clearHazards: clears('hazards'),
      accessNotes: value<String>('access_notes'),
      clearAccessNotes: clears('access_notes'),
      mooringNumber: value<String>('mooring_number'),
      clearMooringNumber: clears('mooring_number'),
      parkingInfo: value<String>('parking_info'),
      clearParkingInfo: clears('parking_info'),
    );
  }
}
