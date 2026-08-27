import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

/// Builds a self-contained SQL subquery `SELECT id FROM dives WHERE ...` that
/// selects the ids of all dives matching [filter], mirroring
/// [DiveFilterState.apply] semantics exactly.
///
/// [params] are raw bind values (ints/strings/doubles) in the same order as
/// the `?` placeholders in [subquery]. Returns an empty no-op
/// (`subquery: ''`, `params: []`) when the filter has no translatable active
/// axes, so callers can skip injecting anything.
({String subquery, List<Object?> params}) buildFilteredDiveIdSubquery(
  DiveFilterState filter,
) {
  final conditions = <String>[];
  final params = <Object?>[];

  // Date range. dive_date_time is epoch MILLISECONDS (wall-clock-as-UTC).
  if (filter.startDate != null) {
    conditions.add('dive_date_time >= ?');
    params.add(filter.startDate!.millisecondsSinceEpoch);
  }
  if (filter.endDate != null) {
    // apply() keeps dives up to endDate + 1 day (inclusive of the end day).
    conditions.add('dive_date_time <= ?');
    params.add(
      filter.endDate!.add(const Duration(days: 1)).millisecondsSinceEpoch,
    );
  }

  // Dive type: membership against the many-to-many junction.
  if (filter.diveTypeId != null) {
    conditions.add(
      'id IN (SELECT dive_id FROM dive_dive_types WHERE dive_type_id = ?)',
    );
    params.add(filter.diveTypeId);
  }

  if (filter.siteId != null) {
    conditions.add('site_id = ?');
    params.add(filter.siteId);
  }
  if (filter.tripId != null) {
    conditions.add('trip_id = ?');
    params.add(filter.tripId);
  }
  if (filter.diveCenterId != null) {
    conditions.add('dive_center_id = ?');
    params.add(filter.diveCenterId);
  }

  // Tags: match ANY selected tag.
  if (filter.tagIds.isNotEmpty) {
    final ph = List.filled(filter.tagIds.length, '?').join(', ');
    conditions.add(
      'id IN (SELECT dive_id FROM dive_tags WHERE tag_id IN ($ph))',
    );
    params.addAll(filter.tagIds);
  }

  // Weekdays: match ANY selected weekday. dive_date_time is wall-clock-as-UTC
  // epoch ms, so strftime('%w', ...) (0=Sunday..6=Saturday) already lines up
  // with the wall-clock day -- no 'utc' modifier needed. Converting
  // DateTime.weekday (1=Monday..7=Sunday) via `% 7` matches that numbering.
  if (filter.weekdays.isNotEmpty) {
    final ph = List.filled(filter.weekdays.length, '?').join(', ');
    conditions.add(
      "CAST(strftime('%w', dive_date_time / 1000, 'unixepoch') AS INTEGER) "
      'IN ($ph)',
    );
    params.addAll(filter.weekdays.map((w) => w % 7));
  }

  // Equipment: match ANY selected item.
  if (filter.equipmentIds.isNotEmpty) {
    final ph = List.filled(filter.equipmentIds.length, '?').join(', ');
    conditions.add(
      'id IN (SELECT dive_id FROM dive_equipment WHERE equipment_id IN ($ph))',
    );
    params.addAll(filter.equipmentIds);
  }

  // Equipment attribute: dives linked to an equipment item whose curated
  // attribute matches. value_num bounds are canonical metric.
  if (filter.equipmentAttrKey != null) {
    // The "Suit thickness" axis (thickness_mm) must match only exposure suits,
    // mirroring getDivesBySuitThickness(): the same attr_key also exists on
    // hoods/gloves/boots, which are not suits.
    final suitOnly = filter.equipmentAttrKey == EquipmentAttrKeys.thicknessMm;
    final sub = StringBuffer(
      'id IN (SELECT de.dive_id FROM dive_equipment de '
      'JOIN equipment_attributes ea ON ea.equipment_id = de.equipment_id ',
    );
    if (suitOnly) {
      sub.write(
        "JOIN equipment eqf ON eqf.id = de.equipment_id "
        "AND eqf.type IN ('wetsuit', 'drysuit') ",
      );
    }
    sub.write('WHERE ea.attr_key = ? AND ea.is_custom = 0');
    params.add(filter.equipmentAttrKey);
    if (filter.equipmentAttrChoice != null) {
      sub.write(' AND ea.value_text = ?');
      params.add(filter.equipmentAttrChoice);
    }
    if (filter.equipmentAttrMin != null) {
      sub.write(' AND ea.value_num >= ?');
      params.add(filter.equipmentAttrMin);
    }
    if (filter.equipmentAttrMax != null) {
      sub.write(' AND ea.value_num <= ?');
      params.add(filter.equipmentAttrMax);
    }
    sub.write(')');
    conditions.add(sub.toString());
  }

  // Depth: null depth excluded when a bound is set.
  if (filter.minDepth != null) {
    conditions.add('max_depth IS NOT NULL AND max_depth >= ?');
    params.add(filter.minDepth);
  }
  if (filter.maxDepth != null) {
    conditions.add('max_depth IS NOT NULL AND max_depth <= ?');
    params.add(filter.maxDepth);
  }

  if (filter.favoritesOnly == true) {
    conditions.add('is_favorite = 1');
  }

  if (filter.decoOnly != null) {
    conditions.add(
      decoSignalCondition(wantDeco: filter.decoOnly!, diveIdRef: 'dives.id'),
    );
  }

  // No buddy: neither the legacy scalar column nor a junction-linked buddy
  // is set, mirroring DiveRepository and DiveFilterState.apply.
  if (filter.noBuddyOnly == true) {
    conditions.add(
      "(buddy IS NULL OR buddy = '') AND "
      'NOT EXISTS (SELECT 1 FROM dive_buddies WHERE dive_buddies.dive_id = dives.id)',
    );
  }

  // Buddy free-text: case-insensitive substring against the legacy scalar
  // column OR any junction-linked buddy's name. The dive editor writes only
  // the dive_buddies junction; the scalar covers old data (#757).
  // Comma-separated names must each match (AND semantics), mirroring
  // DiveRepository and DiveFilterState.apply.
  if (filter.buddyNameFilter != null && filter.buddyNameFilter!.isNotEmpty) {
    final names = filter.buddyNameFilter!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final name in names) {
      conditions.add(
        "((buddy IS NOT NULL AND LOWER(buddy) LIKE '%' || LOWER(?) || '%') "
        'OR id IN (SELECT db.dive_id FROM dive_buddies db '
        'JOIN buddies b ON b.id = db.buddy_id '
        "WHERE LOWER(b.name) LIKE '%' || LOWER(?) || '%'))",
      );
      params.add(name);
      params.add(name);
    }
  }

  if (filter.diveIds.isNotEmpty) {
    final ph = List.filled(filter.diveIds.length, '?').join(', ');
    conditions.add('id IN ($ph)');
    params.addAll(filter.diveIds);
  }

  // Gas O2: ANY tank within the present bounds (dives with no tanks excluded).
  if (filter.minO2Percent != null || filter.maxO2Percent != null) {
    final tankConds = <String>[];
    if (filter.minO2Percent != null) {
      tankConds.add('o2_percent >= ?');
      params.add(filter.minO2Percent);
    }
    if (filter.maxO2Percent != null) {
      tankConds.add('o2_percent <= ?');
      params.add(filter.maxO2Percent);
    }
    conditions.add(
      'id IN (SELECT dive_id FROM dive_tanks WHERE ${tankConds.join(' AND ')})',
    );
  }

  if (filter.minRating != null) {
    conditions.add('rating IS NOT NULL AND rating >= ?');
    params.add(filter.minRating);
  }

  // Bottom time: compare truncated whole minutes, mirroring Duration.inMinutes.
  if (filter.minBottomTimeMinutes != null) {
    conditions.add('bottom_time IS NOT NULL AND bottom_time / 60 >= ?');
    params.add(filter.minBottomTimeMinutes);
  }
  if (filter.maxBottomTimeMinutes != null) {
    conditions.add('bottom_time IS NOT NULL AND bottom_time / 60 <= ?');
    params.add(filter.maxBottomTimeMinutes);
  }

  if (filter.computerId != null) {
    conditions.add('computer_id = ?');
    params.add(filter.computerId);
  }

  // Custom fields: key match + optional value substring.
  if (filter.customFieldKey != null && filter.customFieldKey!.isNotEmpty) {
    if (filter.customFieldValue != null &&
        filter.customFieldValue!.isNotEmpty) {
      conditions.add(
        "id IN (SELECT dive_id FROM dive_custom_fields "
        "WHERE field_key = ? AND LOWER(field_value) LIKE '%' || LOWER(?) || '%')",
      );
      params.add(filter.customFieldKey);
      params.add(filter.customFieldValue);
    } else {
      conditions.add(
        'id IN (SELECT dive_id FROM dive_custom_fields WHERE field_key = ?)',
      );
      params.add(filter.customFieldKey);
    }
  }

  if (conditions.isEmpty) {
    return (subquery: '', params: const <Object?>[]);
  }
  return (
    subquery: 'SELECT id FROM dives WHERE ${conditions.join(' AND ')}',
    params: params,
  );
}

/// Recorded deco-signal SQL condition (no bind params), shared by
/// [buildFilteredDiveIdSubquery], `DiveRepository._buildFilterWhereClauses`
/// and `DiveRepository.getDiveIdsWithDecoSignal` so the three SQL paths
/// (Statistics, the paginated dive list, and the id set the entity-backed
/// surfaces intersect with) can't drift apart. Mirrors
/// `StatisticsRepository.scanRecordedDecoSignals`:
///
/// - A deco-stop profile point (`deco_type = 2`) or a `decoStopStart` event
///   means deco.
/// - A profile that carries `deco_type` values, none of which is 2, means
///   no-deco: the computer recorded obligations and reported none.
/// - A positive `ceiling` on a profile with no `deco_type` at all also means
///   deco (some import sources only ever write a stop depth).
/// - A dive with no qualifying profile data matches neither branch; it is
///   only classifiable via the computed fallback, which this SQL-only axis
///   does not have access to.
///
/// This is the only place the deco axis is evaluated. `DiveFilterState.apply`
/// deliberately skips it, because list-view entities carry neither profile
/// points nor deco-stop events.
///
/// [diveIdRef] must be a reference to the enclosing query's `dives.id`
/// resolvable from inside these correlated subqueries (e.g. `d.id` when the
/// caller aliases `dives` as `d`, or `dives.id` when it does not).
String decoSignalCondition({
  required bool wantDeco,
  required String diveIdRef,
}) {
  final hasDecoStop =
      'EXISTS (SELECT 1 FROM dive_profiles p '
      'WHERE p.dive_id = $diveIdRef AND p.deco_type = 2) '
      "OR EXISTS (SELECT 1 FROM dive_profile_events e "
      "WHERE e.dive_id = $diveIdRef AND e.event_type = 'decoStopStart')";
  final hasDecoType =
      'EXISTS (SELECT 1 FROM dive_profiles p '
      'WHERE p.dive_id = $diveIdRef AND p.deco_type IS NOT NULL)';
  final hasPositiveCeiling =
      'EXISTS (SELECT 1 FROM dive_profiles p '
      'WHERE p.dive_id = $diveIdRef AND p.ceiling > 0)';

  if (wantDeco) {
    return '($hasDecoStop OR (NOT ($hasDecoType) AND $hasPositiveCeiling))';
  }
  return '($hasDecoType AND NOT ($hasDecoStop))';
}
