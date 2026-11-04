import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/enums.dart'
    show EquipmentType, TankMaterial;
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_item_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/gas_fraction_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/data/services/trip_fill_saver.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';

/// A trip's cylinder board, through the repository the board and its sheets
/// use: a slot is a rental or one of the diver's own tanks, added last and
/// moved to a position the board holds; a delete takes its ledger.
class TripCylinderWrites extends WritableEntry {
  TripCylinderWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'trip_cylinders';

  @override
  String get table => 'trip_cylinders';

  @override
  ChildOf get parent => const ChildOf(entity: 'trips', field: 'trip_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'trip_id': const FieldCodec.reference('trips'),
    'equipment_id': const FieldCodec.reference('equipment', nullable: true),
    'label': const FieldCodec.text(maxLength: 100, trim: true),
    'volume_l': const FieldCodec.number(min: 0.1, max: 100, nullable: true),
    'working_pressure_bar': const FieldCodec.number(
      min: 1,
      max: 400,
      nullable: true,
    ),
    'material': FieldCodec.enumName(TankMaterial.values, nullable: true),
    'preset_name': const FieldCodec.text(
      maxLength: 60,
      nullable: true,
      trim: true,
    ),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'label'};

  /// A slot's place on the board, the number [update] takes.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final slots = await _r.tripCylinders.getCylindersForTrip(
      document['trip_id']! as String,
    );
    return {...document, 'sort_order': slots.indexWhere((s) => s.id == id)};
  }

  @override
  UniqueClaim? uniqueKey(WriteCheck check) =>
      switch (check.values['equipment_id']) {
        final String itemId => UniqueClaim(
          'board/${check.values['trip_id'] ?? check.document?['trip_id']}/'
          '$itemId',
        ),
        _ => null,
      };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final tripId =
        check.values['trip_id'] as String? ??
        check.document!['trip_id']! as String;
    final slots = await _r.tripCylinders.getCylindersForTrip(tripId);
    if (check.values['sort_order'] case final int slot) {
      if (check.kind == ChangeKind.create) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'sort_order: a new slot goes last; move it with an update.',
        );
      }
      if (slot >= slots.length) {
        return PlanBlock(
          BlockReason.invalidValue,
          'sort_order: this board holds positions 0 to ${slots.length - 1}.',
        );
      }
    }
    final itemId = check.values['equipment_id'];
    if (itemId is! String) return null;
    final item = await _r.equipment.getEquipmentById(itemId);
    if (item != null &&
        (item.type != EquipmentType.tank ||
            !inKitSoFar(check.soFar, itemId, stored: item.isActive))) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'equipment_id: an own slot is a tank in the kit.',
      );
    }
    if (slots.any((s) => s.equipmentId == itemId && s.id != check.id)) {
      return const PlanBlock(
        BlockReason.duplicateRecord,
        'equipment_id: that tank is on the board already.',
      );
    }
    return null;
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(
    parts: await countCascaded('trip_cylinders', id),
    unlinked: await countUnlinked('trip_cylinders', id),
  );

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final tripId = values['trip_id']! as String;
    final now = DateTime.now();
    final existing = await _r.tripCylinders.getCylindersForTrip(tripId);
    final slot = _applied(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: values['label']! as String,
        sortOrder: nextTripCylinderSortOrder(existing),
        createdAt: now,
        updatedAt: now,
      ),
      values,
    );
    return (await _r.tripCylinders.createCylinders([slot])).single.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _slot(id);
    final v = update.values;
    if (v.keys.any((k) => k != 'sort_order')) {
      await _r.tripCylinders.updateCylinder(_applied(current, v));
    }
    if (v['sort_order'] case final int slot) {
      final ordered = [
        for (final s in await _r.tripCylinders.getCylindersForTrip(
          current.tripId,
        ))
          if (s.id != id) s.id,
      ]..insert(slot, id);
      await _r.tripCylinders.reorderCylinders(ordered);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.tripCylinders.deleteCylinder(id);

  Future<TripCylinder> _slot(String id) async {
    final rows = await _r.db
        .customSelect(
          'SELECT trip_id FROM trip_cylinders WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    final slots = rows.isEmpty
        ? const <TripCylinder>[]
        : await _r.tripCylinders.getCylindersForTrip(
            rows.single.read<String>('trip_id'),
          );
    return slots.where((s) => s.id == id).firstOrNull ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Trip cylinder $id no longer exists.',
          details: {'id': id},
        ));
  }

  static TripCylinder _applied(TripCylinder slot, Map<String, Object?> values) {
    T? kept<T>(String key, T? held) =>
        values.containsKey(key) ? values[key] as T? : held;
    final material = kept('material', slot.material?.name);
    return slot.copyWith(
      equipmentId: kept('equipment_id', slot.equipmentId),
      label: values['label'] as String?,
      volume: kept<num>('volume_l', slot.volume)?.toDouble(),
      workingPressure: kept<num>(
        'working_pressure_bar',
        slot.workingPressure,
      )?.toDouble(),
      material: material == null ? null : TankMaterial.values.byName(material),
      presetName: kept('preset_name', slot.presetName),
      notes: values['notes'] as String?,
    );
  }
}

/// A slot's ledger: fills through the fill sheet's saver, which also copies
/// a fill on one of the diver's own cylinders to its passport, and
/// adjustments through the adjust sheet. The wire gives the gas as
/// fractions, as a read lists them; the store keeps percent.
class TripCylinderEventWrites extends WritableEntry {
  TripCylinderEventWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'trip_cylinder_events';

  @override
  String get table => 'trip_cylinder_events';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'trip_cylinders', field: 'trip_cylinder_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'trip_cylinder_id': const FieldCodec.reference('trip_cylinders'),
    'kind': FieldCodec.enumName(TripCylinderEventKind.values),
    // A wall clock, as the sheets store an event's time.
    'occurred_time': const FieldCodec.wallClock(),
    'bottle_label': const FieldCodec.text(
      maxLength: 60,
      nullable: true,
      trim: true,
    ),
    'pressure_bar': const FieldCodec.number(min: 0, max: 400, nullable: true),
    for (final key in const [
      'o2_fraction',
      'he_fraction',
      'analyzed_o2_fraction',
      'analyzed_he_fraction',
    ])
      key: const FieldCodec.number(min: 0, max: 1, nullable: true),
    'dive_center_id': const FieldCodec.reference('centers', nullable: true),
    'cost': const FieldCodec.number(min: 0, max: 1000000, nullable: true),
    'currency': const FieldCodec.text(maxLength: 3, nullable: true, trim: true),
    'is_package': const FieldCodec.flag(),
    'note': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'kind'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    if (check.kind == ChangeKind.update && check.values.containsKey('kind')) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'kind: a fill stays a fill and an adjustment an adjustment.',
      );
    }
    Object? held(String key) => check.values.containsKey(key)
        ? check.values[key]
        : check.document?[key];
    double? number(String key) => (held(key) as num?)?.toDouble();
    final kind = held('kind');
    final o2 = number('o2_fraction');
    final he = number('he_fraction');
    PlanBlock invalid(String why) => PlanBlock(BlockReason.invalidValue, why);
    if (he != null && he > 0 && o2 == null) {
      return invalid('he_fraction: a mix with helium names its oxygen.');
    }
    if (number('analyzed_he_fraction') != null &&
        number('analyzed_o2_fraction') == null) {
      return invalid(
        'analyzed_he_fraction: an analysed helium names the analysed oxygen.',
      );
    }
    if (o2 != null && (o2 < 0.01 || (he ?? 0) > 0.99 || o2 + (he ?? 0) > 1)) {
      return invalid(
        'o2_fraction, he_fraction: oxygen from 0.01, helium to 0.99, the two '
        'together at most 1.',
      );
    }
    if (kind == TripCylinderEventKind.fill.name) {
      final pressure = number('pressure_bar');
      if (pressure == null || pressure < 1) {
        return invalid('pressure_bar: a fill reaches at least 1 bar.');
      }
    }
    if (held('currency') != null && held('cost') == null) {
      return invalid('currency: a currency goes with a cost.');
    }
    final at = held('occurred_time');
    if (at is DateTime && (at.year < 2000 || at.year > 2100)) {
      return invalid('occurred_time: from 2000 to 2100.');
    }
    return null;
  }

  /// What the fill sheet starts a fill with: air, now as a wall clock, and
  /// the diver's currency when a cost is named.
  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {
    'occurred_time': asWallClockUtc(DateTime.now()),
    if (values['kind'] == TripCylinderEventKind.fill.name) ...{
      'o2_fraction': 0.21,
      'he_fraction': 0.0,
    },
    if (values['kind'] == TripCylinderEventKind.adjustment.name &&
        values['o2_fraction'] != null)
      'he_fraction': 0.0,
  };

  /// A fill on one of the diver's own cylinders is copied to its passport.
  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async {
    if (values['kind'] != TripCylinderEventKind.fill.name) return const {};
    final slot = await _slotOf(values['trip_cylinder_id']! as String);
    if (slot?.equipmentId == null) return const {};
    final minted = await _r.cylinderPassports.getPassportId(slot!.equipmentId!);
    return {'cylinder_fills': 1, if (minted == null) 'equipment_attributes': 1};
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final copy = await _r.cylinderFills.getById(tripFillPassportCopyId(id));
    return DeleteReach(records: {if (copy != null) 'cylinder_fills': 1});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final event = _applied(
      TripCylinderEvent(
        id: '',
        tripCylinderId: values['trip_cylinder_id']! as String,
        kind: TripCylinderEventKind.values.byName(values['kind']! as String),
        occurredAt: values['occurred_time']! as DateTime,
        createdAt: now,
        updatedAt: now,
      ),
      values,
    );
    if (event.kind == TripCylinderEventKind.adjustment) {
      return (await _r.tripCylinders.createEvent(event)).id;
    }
    final saver = TripFillSaver(
      repository: _r.tripCylinders,
      copier: TripFillPassportCopier(),
    );
    final saved = (await saver.writeFills([event])).single;
    final slot = (await _slotOf(event.tripCylinderId))!;
    await saver.copyToPassports(
      [saved],
      {slot.id: slot},
      diverId: diverId,
      stationName: await _stationName(saved.diveCenterId),
    );
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _event(id);
    final next = _applied(current, update.values);
    await _r.tripCylinders.updateEvent(next);
    if (next.kind == TripCylinderEventKind.fill) {
      final slot = (await _slotOf(next.tripCylinderId))!;
      await TripFillPassportCopier().afterSave(
        next,
        slot,
        diverId: ownerId,
        stationName: await _stationName(next.diveCenterId),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.tripCylinders.deleteEvent(
        id,
        alongside: () => TripFillPassportCopier().afterDelete(id),
      );

  Future<String?> _stationName(String? centerId) async => centerId == null
      ? null
      : (await _r.centers.getDiveCenterById(centerId))?.name;

  Future<TripCylinder?> _slotOf(String slotId) async {
    final rows = await _r.db
        .customSelect(
          'SELECT trip_id FROM trip_cylinders WHERE id = ?',
          variables: [Variable.withString(slotId)],
        )
        .get();
    if (rows.isEmpty) return null;
    return (await _r.tripCylinders.getCylindersForTrip(
      rows.single.read<String>('trip_id'),
    )).where((s) => s.id == slotId).firstOrNull;
  }

  Future<TripCylinderEvent> _event(String id) async {
    final rows = await _r.db
        .customSelect(
          'SELECT trip_cylinder_id FROM trip_cylinder_events WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    final events = rows.isEmpty
        ? const <TripCylinderEvent>[]
        : await _r.tripCylinders.getEventsForCylinder(
            rows.single.read<String>('trip_cylinder_id'),
          );
    return events.where((e) => e.id == id).firstOrNull ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Trip cylinder event $id no longer exists.',
          details: {'id': id},
        ));
  }

  static TripCylinderEvent _applied(
    TripCylinderEvent event,
    Map<String, Object?> v,
  ) {
    Object? kept(String key, Object? held) =>
        v.containsKey(key) ? v[key] : held;
    final currency = kept('currency', event.currency) as String?;
    return event.copyWith(
      occurredAt: v['occurred_time'] as DateTime?,
      bottleLabel: kept('bottle_label', event.bottleLabel),
      pressure: (kept('pressure_bar', event.pressure) as num?)?.toDouble(),
      o2Percent: v.containsKey('o2_fraction')
          ? percentOf(v['o2_fraction'])
          : event.o2Percent,
      hePercent: v.containsKey('he_fraction')
          ? percentOf(v['he_fraction'])
          : event.hePercent,
      analyzedO2: v.containsKey('analyzed_o2_fraction')
          ? percentOf(v['analyzed_o2_fraction'])
          : event.analyzedO2,
      analyzedHe: v.containsKey('analyzed_he_fraction')
          ? percentOf(v['analyzed_he_fraction'])
          : event.analyzedHe,
      diveCenterId: kept('dive_center_id', event.diveCenterId),
      cost: (kept('cost', event.cost) as num?)?.toDouble(),
      currency: currency?.toUpperCase(),
      isPackage: v['is_package'] as bool?,
      note: v['note'] as String?,
    );
  }
}
