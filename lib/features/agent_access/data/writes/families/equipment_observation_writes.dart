import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/domain/constants/observation_tag_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/services/observation_defaults.dart';

/// Re-runs the condition findings of these gear items, as the check-in,
/// incident and transmitter pages do after a save.
typedef ConditionFindingsRefresh = void Function(Iterable<String> equipmentIds);

/// Gear check-ins, through the repository the check-in sheet uses. A
/// check-in is ok, or an issue with one or more of the item type's tags; it
/// may name the dive it was made on. The sheet refreshes the item's
/// condition findings after a save, so the apply does too.
class EquipmentObservationWrites extends WritableEntry {
  EquipmentObservationWrites(
    this._r, {
    ConditionFindingsRefresh? refreshFindings,
  }) : _refreshFindings = refreshFindings ?? scheduleConditionFindingsRefresh;

  final RecordRepositories _r;
  final ConditionFindingsRefresh _refreshFindings;

  @override
  String get name => 'equipment_observations';

  @override
  String get table => 'equipment_observations';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'equipment_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'equipment_id': const FieldCodec.reference('equipment'),
    'dive_id': const FieldCodec.reference('dives', nullable: true),
    'status': FieldCodec.enumName(ObservationStatus.values),
    'issue_tags': FieldCodec.enumSet(ObservationTag.values),
    'note': const FieldCodec.text(allowBlank: true, trim: true),
    // A wall clock, as the sheet stores a check-in's time.
    'observed_time': const FieldCodec.wallClock(),
  };

  @override
  Set<String> get requiredOnCreate => const {'status'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final status =
        check.values['status'] as String? ??
        check.document?['status'] as String?;
    final tags = check.values.containsKey('issue_tags')
        ? _tags(check.values['issue_tags'])
        : [
            for (final name
                in (check.document?['issue_tags'] as List?) ?? const [])
              ObservationTag.values.byName(name as String),
          ];
    if (status == ObservationStatus.ok.name && tags.isNotEmpty) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'issue_tags: an ok check-in carries no tags; send an empty list.',
      );
    }
    final unrecognized =
        (check.document?['unrecognized_tags'] as List?)?.isNotEmpty ?? false;
    if (status == ObservationStatus.issue.name &&
        tags.isEmpty &&
        !unrecognized) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'issue_tags: an issue names at least one tag.',
      );
    }
    final itemId =
        check.values['equipment_id'] as String? ??
        check.document!['equipment_id']! as String;
    final item = await _r.equipment.getEquipmentById(itemId);
    if (item == null) return null;
    final offered = observationTagsFor(item.type).toSet();
    final foreign = [
      for (final tag in tags)
        if (!offered.contains(tag)) tag.name,
    ];
    if (foreign.isNotEmpty) {
      return PlanBlock(
        BlockReason.invalidValue,
        'issue_tags: ${foreign.join(', ')} is not offered for a '
        '${item.type.name}; these are: '
        '${offered.map((t) => t.name).join(', ')}.',
      );
    }
    return null;
  }

  static List<ObservationTag> _tags(Object? parsed) => [
    if (parsed is String)
      for (final name in parsed.split(','))
        if (name.isNotEmpty) ObservationTag.values.byName(name),
  ];

  /// The sheet's time for a new check-in: the dive's end when it names one,
  /// else now, both as wall clocks.
  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final diveId = values['dive_id'] as String?;
    final dive = diveId == null ? null : await _r.dives.getDiveById(diveId);
    return {
      'observed_time': dive == null
          ? asWallClockUtc(DateTime.now())
          : defaultObservedAt(dive),
    };
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final status = ObservationStatus.values.byName(values['status']! as String);
    return (await _r.equipmentObservations.create(
      equipmentId: values['equipment_id']! as String,
      diveId: values['dive_id'] as String?,
      diverId: diverId,
      observedAt: values['observed_time']! as DateTime,
      status: status,
      issueTags: _tags(values['issue_tags']),
      note: values['note'] as String? ?? '',
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.equipmentObservations.getById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Check-in $id no longer exists.',
          details: {'id': id},
        ));
    final v = update.values;
    await _r.equipmentObservations.update(
      current.copyWith(
        status: v['status'] == null
            ? null
            : ObservationStatus.values.byName(v['status']! as String),
        issueTags: v.containsKey('issue_tags') ? _tags(v['issue_tags']) : null,
        diveId: v['dive_id'] as String?,
        clearDiveId: v.containsKey('dive_id') && v['dive_id'] == null,
        note: v['note'] as String?,
        observedAt: v['observed_time'] as DateTime?,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.equipmentObservations.delete(id);

  /// Turning an issue to ok unlinks the near-miss reports that stood on it.
  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final status = update.values['status'];
    if (status != ObservationStatus.ok.name ||
        document['status'] == ObservationStatus.ok.name) {
      return const SideEffects();
    }
    return SideEffects(touched: await _incidents(id));
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(touched: await _incidents(id));

  static Future<Map<String, int>> _incidents(String id) async {
    final n = await countRows('incidents', 'observation_id = ?1', id);
    return {if (n > 0) 'incidents': n};
  }

  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    final items = <String>{
      for (final c in changes)
        if (c.parentId case final id? when run.once(('findings', id))) id,
    };
    if (items.isNotEmpty) _refreshFindings(items);
  }
}
