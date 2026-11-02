import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DivesCompanion;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Dives write through the bulk edit service, so an agent's change behaves as
/// the diver's own bulk edit does: the site's values snap on, a tank keeps no
/// link into a trip the dive left, and sync hears once.
class DiveWrites implements WritableEntry {
  DiveWrites(this._r)
    : _edits = BulkDiveEditService(_r.dives, _r.buddies, _r.species);

  final RecordRepositories _r;
  final BulkDiveEditService _edits;

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

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async => null;

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
    return DivesCompanion(
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
        if (await _r.buddies.getBuddyById(id) case final buddy?)
          BuddyWithRole(buddy: buddy, roles: [role]),
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

  Future<DiveRole> _buddyRole() async {
    final roles = await _r.diveRoles.getAllDiveRoles();
    return roles.firstWhere((role) => role.id == DiveRole.buddyId);
  }
}

T? _enum<T extends Enum>(List<T> values, Object? name) =>
    name == null ? null : values.byName(name as String);
