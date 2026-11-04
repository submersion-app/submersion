import 'package:drift/drift.dart' show Value, Variable;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show Dive, DivesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_link_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/trip_rules.dart'
    show foreignSlotLinks;
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart'
    show DiveGearPreview;
import 'package:submersion/features/dive_log/data/repositories/dive_site_snap.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;

/// Dives write through the bulk edit service, so an agent's change behaves as
/// the diver's own bulk edit does: the site's values snap on, a tank keeps no
/// link into a trip the dive left, and sync hears once.
class DiveWrites extends WritableEntry {
  DiveWrites(this._r);

  final RecordRepositories _r;
  late final _edits = BulkDiveEditService(_r.dives, _r.buddies, _r.species);
  final _roleLinks = DiveRoleLinkRepository();
  final _annotations = AnnotationRepository();

  @override
  String get name => 'dives';

  @override
  String get table => 'dives';

  static const _text = FieldCodec.text(maxLength: 500, nullable: true);

  @override
  late final Map<String, FieldCodec> fields = {
    'name': _text,
    'notes': const FieldCodec.text(allowBlank: true),
    'date_time': const FieldCodec.wallClock(),
    'max_depth_m': const FieldCodec.number(min: 0, max: 350, nullable: true),
    'avg_depth_m': const FieldCodec.number(min: 0, max: 350, nullable: true),
    'water_temp_c': const FieldCodec.number(min: -3, max: 45, nullable: true),
    'air_temp_c': const FieldCodec.number(min: -60, max: 60, nullable: true),
    'visibility': FieldCodec.enumName(Visibility.values, nullable: true),
    'rating': const FieldCodec.integer(min: 0, max: 5, nullable: true),
    'is_favorite': const FieldCodec.flag(),
    'excluded_from_stats': const FieldCodec.flag(),
    'excluded_from_gas_stats': const FieldCodec.flag(),
    'dive_operator': _text,
    'boat_name': _text,
    'boat_captain': _text,
    'dive_master': _text,
    'buddy': _text,
    'current_direction': FieldCodec.enumName(
      CurrentDirection.values,
      nullable: true,
    ),
    'current_strength': FieldCodec.enumName(
      CurrentStrength.values,
      nullable: true,
    ),
    'swell_height_m': const FieldCodec.number(min: 0, max: 30, nullable: true),
    'surface_conditions': _text,
    'entry_method': FieldCodec.enumName(EntryMethod.values, nullable: true),
    'exit_method': FieldCodec.enumName(EntryMethod.values, nullable: true),
    'water_type': FieldCodec.enumName(WaterType.values, nullable: true),
    'altitude_m': const FieldCodec.number(min: -500, max: 6000, nullable: true),
    'weather_description': _text,
    'buddy_roles': const FieldCodec.idLists(),
  };

  @override
  Map<String, RelationSpec> get relations => const {
    'buddies': RelationSpec(refEntity: 'buddies'),
    'tags': RelationSpec(refEntity: 'tags'),
    'types': RelationSpec(refEntity: 'dive_types'),
    'site': RelationSpec(refEntity: 'sites', single: true, copiesTarget: true),
    'gear': RelationSpec(refEntity: 'equipment'),
    'courses': RelationSpec(refEntity: 'courses'),
    'roles': RelationSpec(refEntity: 'dive_roles'),
    'trip': RelationSpec(refEntity: 'trips', single: true),
  };

  @override
  String get note =>
      'buddy_roles names every buddy on the dive, each with its role ids '
      '(an empty list is Buddy), and replaces the list; buddies adds or '
      'removes buddies as Buddy. A dive put on a trip, or moved to another '
      'day on one, stretches the trip to cover it.';

  @override
  Set<String> get requiredOnCreate => const {'date_time'};

  /// Naming a band clears any measurement, the band it already holds included.
  @override
  Set<String> get effectFields => const {'visibility'};

  @override
  Future<Set<String>> currentRelation(String id, String relation) async {
    if (relation == 'buddies') {
      return {
        for (final b in await _r.buddies.getBuddiesForDive(id)) b.buddy.id,
      };
    }
    // Each from its own rows: a full dive read decodes the profile, and a
    // plan asks for these again at apply, inside the write transaction.
    return switch (relation) {
      'tags' => {for (final t in await _r.tags.getTagsForDive(id)) t.id},
      'types' => _types(id),
      'site' => {?(await _row(id))?.siteId},
      'gear' => _ids('dive_equipment', 'equipment_id', id),
      'courses' => _ids('dive_courses', 'course_id', id),
      'roles' => (await _roles(id)).toSet(),
      'trip' => {?(await _row(id))?.tripId},
      _ => const {},
    };
  }

  /// The [column] of every row of [table] on dive [id].
  Future<Set<String>> _ids(String table, String column, String id) async {
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT $column FROM $table WHERE dive_id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return {for (final row in rows) row.read<String>(column)};
  }

  /// A role normalize would drop, as it drops Solo beside any other role,
  /// would be planned as added and never written.
  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.values.containsKey('buddy_roles')) {
      if (check.relations['buddies'] case final delta? when !delta.isEmpty) {
        return const PlanBlock(
          BlockReason.notPermitted,
          'buddy_roles replaces the buddy list; change buddies in another '
          'change.',
        );
      }
      final problem = await buddyRolesProblem(
        _r,
        check.values['buddy_roles'],
        check.ownerId,
      );
      if (problem != null) return problem;
    }
    final roles = check.relations['roles'];
    if (roles == null || check.id == null) return null;
    final after = (await _rolesAfter(check.id!, roles)).toSet();
    final dropped = roles.add.difference(after);
    if (dropped.isEmpty) return null;
    return PlanBlock(
      BlockReason.invalidValue,
      'roles: ${dropped.join(', ')} cannot sit beside the dive\'s other '
      'roles. Remove those in the same change.',
    );
  }

  /// A dive with no type links has its one legacy type, as a dive read says.
  Future<Set<String>> _types(String id) async {
    final links = await _ids('dive_dive_types', 'dive_type_id', id);
    if (links.isNotEmpty) return links;
    return {?(await _row(id))?.diveType};
  }

  /// A read fills an empty water temperature from the profile, and a plan
  /// must compare with what the column holds: clearing a value only a sample
  /// shows would change nothing.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final row = await _row(id);
    return {
      ...document,
      'water_temp_c': row?.waterTemp,
      'buddy_roles': await buddyRolesOf(_r, id),
    };
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final fields = <String, Object?>{};
    final relations = <String, Set<String>>{};
    final siteId = update.relations['site']?.add.firstOrNull;
    final row = siteId == null ? null : await _row(id);
    if (siteId != null && row != null) {
      final snap = siteSnapColumns(row, await _r.sites.getSiteById(siteId));
      if (snap.waterType.present) fields['water_type'] = snap.waterType.value;
      if (snap.entryMethod.present) {
        fields['entry_method'] = snap.entryMethod.value;
      }
      if (snap.exitMethod.present) {
        fields['exit_method'] = snap.exitMethod.value;
      }
      final types = (await diveTypeIdsForSite(siteId, ownerId)).toSet();
      final added = types.difference(await currentRelation(id, 'types'));
      if (added.isNotEmpty) relations['types'] = added;
    }
    final lost = <String, Set<String>>{};
    if (update.relations['roles'] case final roles?) {
      // The set is normalized as every role write stores it, which drops
      // Solo beside any other role.
      final now = await currentRelation(id, 'roles');
      final after = (await _rolesAfter(id, roles)).toSet();
      final dropped = now.difference(after).difference(roles.remove);
      if (dropped.isNotEmpty) lost['roles'] = dropped;
    }
    if (update.relations['gear'] case final gear?) {
      // An assembly brings its active parts, and an item taken off takes
      // what is attached through it, as the bulk editor does.
      final now = await currentRelation(id, 'gear');
      final after = await _r.dives.gearIdsAfter(
        id,
        add: gear.add.toList(),
        remove: gear.remove.toList(),
      );
      final gained = after.difference(now).difference(gear.add);
      final dropped = now.difference(after).difference(gear.remove);
      if (gained.isNotEmpty) relations['gear'] = gained;
      if (dropped.isNotEmpty) lost['gear'] = dropped;
    }
    if (update.values['visibility'] != null) {
      for (final key in _measuredVisibility) {
        if (document[key] != null) fields[key] = null;
      }
    }
    final parts = <String, int>{};
    if (update.values['notes'] case final String notes) {
      // An annotation whose link the new Notes drop goes, as an editor
      // save reconciles it.
      final linked = annotationWordsInNotes(notes).keys.toSet();
      final dropped = [
        for (final a in await _annotations.annotationsForDive(id))
          if (!linked.contains(a.id)) a.id,
      ];
      if (dropped.isNotEmpty) parts['dive_profile_events'] = dropped.length;
    }
    if (update.values['date_time'] case final DateTime moved) {
      final offset = moved.difference(
        DateTime.parse(document['date_time']! as String),
      );
      for (final key in const ['entry_time', 'exit_time']) {
        if (document[key] case final String clock) {
          fields[key] = wallClock(DateTime.parse(clock).add(offset));
        }
      }
    }
    final stretched = await _tripsStretched(id, update);
    final trip = update.relations['trip'];
    final slots = trip == null
        ? 0
        : await foreignSlotLinks({id}, trip.add.firstOrNull);
    return SideEffects(
      fields: fields,
      relations: relations,
      lost: lost,
      parts: parts,
      touched: {
        if (stretched > 0) 'trips': stretched,
        if (slots > 0) 'dive_tanks': slots,
      },
    );
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final media = await _r.media.partitionMediaForDiveDeletion([id]);
    final documents = await countDocuments(await deletedDocumentOwners(id));
    final others = [
      for (final dive in alongside['dives'] ?? const <String>{})
        if (dive != id) dive,
    ];
    // The delete reclaims a stored import file once no surviving dive's
    // source names it. Several dives of the set can share one, and it is
    // counted on the last of them by id.
    final files = await countRows(
      'imported_files',
      'id IN (SELECT imported_file_id FROM dive_data_sources '
          'WHERE dive_id = ?1) AND NOT EXISTS (SELECT 1 FROM dive_data_sources s '
          'WHERE s.imported_file_id = imported_files.id AND s.dive_id <> ?1 '
          'AND (s.dive_id > ?1 OR s.dive_id NOT IN (${marksFrom2(others.length)})))',
      id,
      others,
    );
    // A photo held by a site the set also deletes has no link left once both
    // go, so it is counted here and the site leaves it out.
    final sites = [...?alongside['sites']];
    final freed = sites.isEmpty
        ? 0
        : await countRows(
            'media',
            '"dive_id" = ?1 AND "equipment_id" IS NULL '
                'AND "site_id" IN (${marksFrom2(sites.length)})',
            id,
            sites,
          );
    final doomed = media.doomed.length + freed;
    final kept = media.unlinkIds.length - freed;
    return DeleteReach(
      records: {
        if (documents > 0) 'documents': documents,
        if (doomed > 0) 'media': doomed,
        if (files > 0) 'imported_files': files,
      },
      parts: await countCascaded('dives', id),
      unlinked: {
        ...await countUnlinked('dives', id, except: _reportedApart),
        if (kept > 0) 'media': kept,
      },
    );
  }

  @override
  String? titleOf(Map<String, Object?> document) {
    final name = document['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final number = document['dive_number'];
    final site = (document['site'] as Map?)?['name'];
    final title = [if (number != null) '#$number', ?site].join(' ');
    return title.isEmpty ? null : title;
  }

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.dive, id),
  ];

  Future<Dive?> _row(String id) {
    final db = DatabaseService.instance.database;
    return (db.select(
      db.dives,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> v) async {
    final dive = await _r.dives.createDive(
      domain.Dive(
        id: '',
        diverId: diverId,
        diveNumber: await _r.dives.getNextDiveNumber(diverId: diverId),
        dateTime: v['date_time']! as DateTime,
        name: v['name'] as String?,
        notes: v['notes'] as String? ?? '',
        maxDepth: v['max_depth_m'] as double?,
        avgDepth: v['avg_depth_m'] as double?,
        waterTemp: v['water_temp_c'] as double?,
        airTemp: v['air_temp_c'] as double?,
        visibility: _enum(Visibility.values, v['visibility']),
        rating: v['rating'] as int?,
        isFavorite: v['is_favorite'] as bool? ?? false,
        excludedFromStats: v['excluded_from_stats'] as bool? ?? false,
        excludedFromGasStats: v['excluded_from_gas_stats'] as bool? ?? false,
        diveOperator: v['dive_operator'] as String?,
        boatName: v['boat_name'] as String?,
        boatCaptain: v['boat_captain'] as String?,
        diveMaster: v['dive_master'] as String?,
        buddy: v['buddy'] as String?,
        currentDirection: _enum(
          CurrentDirection.values,
          v['current_direction'],
        ),
        currentStrength: _enum(CurrentStrength.values, v['current_strength']),
        swellHeight: v['swell_height_m'] as double?,
        surfaceConditions: v['surface_conditions'] as String?,
        entryMethod: _enum(EntryMethod.values, v['entry_method']),
        exitMethod: _enum(EntryMethod.values, v['exit_method']),
        waterType: _enum(WaterType.values, v['water_type']),
        altitude: v['altitude_m'] as double?,
        weatherDescription: v['weather_description'] as String?,
      ),
    );
    return dive.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final trip = update.relations['trip'];
    final base = _scalars(update.values);
    final scalars = trip == null
        ? base
        : base.copyWith(tripId: Value(trip.add.firstOrNull));
    final ops = await _ops(id, update.relations);
    if (scalars.toColumns(false).isNotEmpty || ops.isNotEmpty) {
      await _edits.apply(
        BulkEditRequest(diveIds: [id], scalars: scalars, ops: ops),
      );
    }
    if (update.values['date_time'] case final DateTime moved) {
      await _moveTo(id, moved);
    }
    if (update.values['notes'] case final String notes) {
      await _annotations.reconcile(diveId: id, notes: notes);
    }
    if (update.values.containsKey('buddy_roles')) {
      await setBuddyRoles(_r, id, update.values['buddy_roles']);
    }
    if (await _tripsStretched(id, update) > 0) {
      await _r.trips.stretchToCoverDives([id]);
    }
  }

  /// How many trips this change makes stretch: a dive put on a trip, or
  /// moved to a day its trip does not cover.
  Future<int> _tripsStretched(String id, RecordUpdate update) async {
    final moved = update.values['date_time'] as DateTime?;
    final trip = update.relations['trip'];
    if (trip == null && moved == null) return 0;
    final tripId = trip == null
        ? (await _row(id))?.tripId
        : trip.add.firstOrNull;
    if (tripId == null) return 0;
    final day = await diveDay(_r, id, moved: moved);
    return day == null ? 0 : tripsStretched(_r, tripId, day);
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      // A revert restores the rows, and its media needs the blobs still there.
      _r.dives.bulkDeleteDives([id], holdRemoteMedia: true);

  /// The clock moves as a shift, so entry and exit keep their place in it.
  Future<void> _moveTo(String id, DateTime when) async {
    final times = await _r.dives.getDiveTimesSnapshot([id]);
    if (times.isEmpty) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Dive $id no longer exists.',
        details: {'id': id},
      );
    }
    final offset = Duration(
      milliseconds: when.millisecondsSinceEpoch - times.single.diveDateTime,
    );
    await _r.dives.bulkShiftDiveTimes([id], offset);
  }

  DivesCompanion _scalars(Map<String, Object?> v) {
    Value<T> field<T>(String key) =>
        v.containsKey(key) ? Value(v[key] as T) : const Value.absent();
    // A band and a measurement contradict each other, so bulk edit never
    // leaves both, and a later save would drop the band anyway.
    final band = v['visibility'] != null;
    Value<double?> measurement() =>
        band ? const Value(null) : const Value.absent();
    return DivesCompanion(
      visibilityMeters: measurement(),
      visibilityMinMeters: measurement(),
      visibilityMaxMeters: measurement(),
      name: field('name'),
      notes: field('notes'),
      maxDepth: field('max_depth_m'),
      avgDepth: field('avg_depth_m'),
      waterTemp: field('water_temp_c'),
      airTemp: field('air_temp_c'),
      visibility: field('visibility'),
      rating: field('rating'),
      isFavorite: field('is_favorite'),
      excludedFromStats: field('excluded_from_stats'),
      excludedFromGasStats: field('excluded_from_gas_stats'),
      diveOperator: field('dive_operator'),
      boatName: field('boat_name'),
      boatCaptain: field('boat_captain'),
      diveMaster: field('dive_master'),
      buddy: field('buddy'),
      currentDirection: field('current_direction'),
      currentStrength: field('current_strength'),
      swellHeight: field('swell_height_m'),
      surfaceConditions: field('surface_conditions'),
      entryMethod: field('entry_method'),
      exitMethod: field('exit_method'),
      waterType: field('water_type'),
      altitude: field('altitude_m'),
      weatherDescription: field('weather_description'),
    );
  }

  Future<List<BulkCollectionOp>> _ops(
    String diveId,
    Map<String, RelationDelta> deltas,
  ) async {
    final ops = <BulkCollectionOp>[];
    for (final MapEntry(key: relation, value: delta) in deltas.entries) {
      if (delta.isEmpty) continue;
      switch (relation) {
        case 'tags':
          if (delta.add.isNotEmpty) {
            ops.add(
              TagsOp(mode: BulkCollectionMode.add, tagIds: delta.add.toList()),
            );
          }
          if (delta.remove.isNotEmpty) {
            ops.add(
              TagsOp(
                mode: BulkCollectionMode.remove,
                tagIds: delta.remove.toList(),
              ),
            );
          }
        case 'types':
          if (delta.add.isNotEmpty) {
            ops.add(
              DiveTypesOp(
                mode: BulkCollectionMode.add,
                diveTypeIds: delta.add.toList(),
              ),
            );
          }
          if (delta.remove.isNotEmpty) {
            ops.add(
              DiveTypesOp(
                mode: BulkCollectionMode.remove,
                diveTypeIds: delta.remove.toList(),
              ),
            );
          }
        case 'gear':
          if (delta.add.isNotEmpty) {
            ops.add(
              EquipmentOp(
                mode: BulkCollectionMode.add,
                equipmentIds: delta.add.toList(),
              ),
            );
          }
          if (delta.remove.isNotEmpty) {
            ops.add(
              EquipmentOp(
                mode: BulkCollectionMode.remove,
                equipmentIds: delta.remove.toList(),
              ),
            );
          }
        case 'roles':
          ops.add(DiverRolesOp(roleIds: await _rolesAfter(diveId, delta)));
        case 'courses':
          if (delta.add.isNotEmpty) {
            ops.add(
              DiveCoursesOp(
                mode: BulkCollectionMode.add,
                courseIds: delta.add.toList(),
              ),
            );
          }
          if (delta.remove.isNotEmpty) {
            ops.add(
              DiveCoursesOp(
                mode: BulkCollectionMode.remove,
                courseIds: delta.remove.toList(),
              ),
            );
          }
        case 'site':
          ops.add(SiteOp(siteId: delta.add.isEmpty ? null : delta.add.first));
        case 'buddies':
          ops.addAll(await _buddyOps(delta));
      }
    }
    return ops;
  }

  /// The diver's roles on [diveId], as a dive read resolves them.
  Future<List<String>> _roles(String diveId) async =>
      (await _roleLinks.diverRoleIdsForDives([diveId]))[diveId] ?? const [];

  /// The roles [delta] leaves on [diveId], normalized as every role write
  /// stores them.
  Future<List<String>> _rolesAfter(String diveId, RelationDelta delta) async =>
      DiveRoleSet.normalize([
        for (final role in await _roles(diveId))
          if (!delta.remove.contains(role)) role,
        ...delta.add,
      ]);

  Future<List<BuddiesOp>> _buddyOps(RelationDelta delta) async {
    final role = await _buddyRole();
    Future<List<BuddyWithRole>> withRole(Set<String> ids) async => [
      for (final id in ids)
        BuddyWithRole(buddy: await _buddy(id), roles: [role]),
    ];
    return [
      if (delta.add.isNotEmpty)
        BuddiesOp(
          mode: BulkCollectionMode.add,
          buddies: await withRole(delta.add),
          overwriteRole: false,
        ),
      if (delta.remove.isNotEmpty)
        BuddiesOp(
          mode: BulkCollectionMode.remove,
          buddies: await withRole(delta.remove),
        ),
    ];
  }

  Future<Buddy> _buddy(String id) async {
    final buddy = await _r.buddies.getBuddyById(id);
    if (buddy != null) return buddy;
    throw AgentToolException(
      AgentToolErrorCode.writeRefused,
      'Buddy $id no longer exists.',
      details: {'id': id},
    );
  }

  Future<DiveRole> _buddyRole() async {
    final roles = await _r.diveRoles.getAllDiveRoles();
    return roles.firstWhere((role) => role.id == DiveRole.buddyId);
  }
}

/// Foreign keys to a dive whose rows [DiveWrites.deleteReach] sorts itself:
/// these go with the dive or stay, record by record.
const _reportedApart = {'documents', 'media'};

const _measuredVisibility = [
  'visibility_m',
  'visibility_min_m',
  'visibility_max_m',
];

T? _enum<T extends Enum>(List<T> values, Object? name) =>
    name == null ? null : values.byName(name as String);
