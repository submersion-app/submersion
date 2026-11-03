import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show Dive, DivesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_site_snap.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwnerKind;

/// Dives write through the bulk edit service, so an agent's change behaves as
/// the diver's own bulk edit does: the site's values snap on, a tank keeps no
/// link into a trip the dive left, and sync hears once.
class DiveWrites extends WritableEntry {
  DiveWrites(this._r);

  final RecordRepositories _r;
  late final _edits = BulkDiveEditService(_r.dives, _r.buddies, _r.species);

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
  };

  @override
  Map<String, RelationSpec> get relations => const {
    'buddies': RelationSpec(refEntity: 'buddies'),
    'tags': RelationSpec(refEntity: 'tags'),
    'types': RelationSpec(refEntity: 'dive_types'),
    'site': RelationSpec(refEntity: 'sites', single: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'date_time'};

  @override
  Future<Set<String>> currentRelation(String id, String relation) async {
    if (relation == 'buddies') {
      return {
        for (final b in await _r.buddies.getBuddiesForDive(id)) b.buddy.id,
      };
    }
    final dive = await _r.dives.getDiveById(id);
    return switch (relation) {
      'tags' => {for (final t in dive?.tags ?? const []) t.id as String},
      'types' => {...?dive?.diveTypeIds},
      'site' => {?dive?.site?.id},
      _ => const {},
    };
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
    return {...document, 'water_temp_c': row?.waterTemp};
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
    if (update.values['visibility'] != null) {
      for (final key in _measuredVisibility) {
        if (document[key] != null) fields[key] = null;
      }
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
    return SideEffects(fields: fields, relations: relations);
  }

  @override
  Future<DeleteReach> deleteReach(String id) async =>
      DeleteReach(records: await countOwned({'documents': 'dive_id'}, id));

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
  DocumentOwnerKind get documentOwner => DocumentOwnerKind.dive;

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
    final scalars = _scalars(update.values);
    final ops = await _ops(update.relations);
    if (scalars.toColumns(false).isNotEmpty || ops.isNotEmpty) {
      await _edits.apply(
        BulkEditRequest(diveIds: [id], scalars: scalars, ops: ops),
      );
    }
    if (update.values['date_time'] case final DateTime moved) {
      await _moveTo(id, moved);
    }
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

  Future<List<BulkCollectionOp>> _ops(Map<String, RelationDelta> deltas) async {
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
        case 'site':
          ops.add(SiteOp(siteId: delta.add.isEmpty ? null : delta.add.first));
        case 'buddies':
          ops.addAll(await _buddyOps(delta));
      }
    }
    return ops;
  }

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

const _measuredVisibility = [
  'visibility_m',
  'visibility_min_m',
  'visibility_max_m',
];

T? _enum<T extends Enum>(List<T> values, Object? name) =>
    name == null ? null : values.byName(name as String);
