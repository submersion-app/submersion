part of 'insights_repository.dart';

/// Dive focus factor rows (issue #1611), kept beside the repository so the
/// main file does not grow further; a part shares its scope helpers.
extension InsightsRepositoryFocus on InsightsRepository {
  /// One row of Dive focus factors per in-scope dive (issue #1611).
  ///
  /// Scoped like every descriptive aggregate. The comparison baseline is
  /// narrowed further by the caller to the dives that have the ranked
  /// metric, so a gas-excluded dive drops out there, not here.
  Future<List<FocusFactorRow>> getFocusFactorRows({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    required VisibilityScale visibilityScale,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      // Drift binds positionally: the visibility thresholds and the Solo
      // role id sit in the SELECT list, ahead of the WHERE placeholders.
      final params = [
        visibilityScale.excellentAtOrAboveM,
        visibilityScale.goodAtOrAboveM,
        visibilityScale.moderateAtOrAboveM,
        DiveRole.soloId,
        ?diverId,
        ...df.params,
      ];

      final results = await _db.customSelect('''
        SELECT
          d.id,
          d.dive_date_time,
          d.entry_time,
          d.max_depth,
          d.avg_depth,
          ${effectiveRuntimeSecondsSql('d')} / 60.0 AS duration_minutes,
          d.water_temp,
          CASE
            WHEN d.visibility_meters IS NOT NULL THEN
              CASE
                WHEN d.visibility_meters >= ? THEN 'excellent'
                WHEN d.visibility_meters >= ? THEN 'good'
                WHEN d.visibility_meters >= ? THEN 'moderate'
                ELSE 'poor'
              END
            ELSE 'legacy_' || NULLIF(d.visibility, '')
          END AS visibility_key,
          NULLIF(d.current_strength, '') AS current_strength,
          COALESCE(NULLIF(d.water_type, ''), NULLIF(s.water_type, ''))
            AS water_type,
          COALESCE(NULLIF(d.entry_method, ''), NULLIF(s.entry_method, ''))
            AS entry_method,
          d.site_id,
          s.name AS site_name,
          (SELECT GROUP_CONCAT(ddt.dive_type_id, char(31))
            FROM dive_dive_types ddt WHERE ddt.dive_id = d.id) AS dive_types,
          (SELECT CASE
              WHEN COUNT(*) = 0 THEN NULL
              WHEN MAX(t.he_percent) > 0 THEN 'trimix'
              WHEN MAX(t.o2_percent) > 21.5 THEN 'nitrox'
              ELSE 'air'
            END
            FROM dive_tanks t WHERE t.dive_id = d.id) AS gas_class,
          (SELECT t.volume FROM dive_tanks t WHERE t.dive_id = d.id
            ORDER BY t.tank_order LIMIT 1) AS first_tank_volume,
          COALESCE(
            (SELECT SUM(w.amount_kg) FROM dive_weights w WHERE w.dive_id = d.id),
            d.weight_amount
          ) AS weight_amount,
          (SELECT CASE
              WHEN COUNT(e.id) = 0 THEN NULL
              WHEN MAX(e.type = 'drysuit') = 1 THEN 'drysuit'
              WHEN MAX(ea.value_num) IS NOT NULL
                THEN 'wetsuit:' || MAX(ea.value_num)
              ELSE 'unknown'
            END
            FROM dive_equipment de
            JOIN equipment e ON e.id = de.equipment_id
              AND e.type IN ('wetsuit', 'drysuit')
            LEFT JOIN equipment_attributes ea ON ea.equipment_id = e.id
              AND e.type = 'wetsuit'
              AND ea.attr_key = 'thickness_mm'
              AND ea.is_custom = 0
              AND ea.value_num IS NOT NULL
            WHERE de.dive_id = d.id) AS suit_key,
          EXISTS (SELECT 1 FROM dive_buddies db WHERE db.dive_id = d.id)
            AS has_linked_buddy,
          NULLIF(TRIM(d.buddy), '') AS buddy_text,
          COALESCE(d.diver_role = ?, 0) AS is_solo
        FROM dives d
        LEFT JOIN dive_sites s ON s.id = d.site_id
        WHERE 1 = 1 $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return [
        for (final row in results)
          FocusFactorRow(
            diveId: row.read<String>('id'),
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('dive_date_time'),
              isUtc: true,
            ),
            entryTime: switch (row.read<int?>('entry_time')) {
              final ms? => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
              null => null,
            },
            maxDepth: row.read<double?>('max_depth'),
            avgDepth: row.read<double?>('avg_depth'),
            durationMinutes: row.read<double?>('duration_minutes'),
            waterTemp: row.read<double?>('water_temp'),
            visibilityKey: row.read<String?>('visibility_key'),
            currentStrength: row.read<String?>('current_strength'),
            waterType: row.read<String?>('water_type'),
            entryMethod: row.read<String?>('entry_method'),
            siteId: row.read<String?>('site_id'),
            siteName: row.read<String?>('site_name'),
            // Unit separator: a dive type id never contains it.
            diveTypes:
                row.read<String?>('dive_types')?.split('\u001f') ?? const [],
            gasClass: row.read<String?>('gas_class'),
            firstTankVolume: row.read<double?>('first_tank_volume'),
            weight: row.read<double?>('weight_amount'),
            suitKey: _focusSuitKey(row.read<String?>('suit_key')),
            buddyKey: _focusBuddyKey(
              hasLinked: row.read<bool>('has_linked_buddy'),
              text: row.read<String?>('buddy_text'),
              isSolo: row.read<bool>('is_solo'),
            ),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive focus factor rows',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

/// SQLite renders a REAL as "5.0"; the key drops a whole number's ".0" so
/// it reads "wetsuit:5" like the progression page's "5 mm".
String? _focusSuitKey(String? raw) {
  if (raw == null || !raw.startsWith('wetsuit:')) return raw;
  final mm = double.tryParse(raw.substring('wetsuit:'.length));
  if (mm == null) return 'unknown';
  return mm == mm.roundToDouble()
      ? 'wetsuit:${mm.toStringAsFixed(0)}'
      : 'wetsuit:$mm';
}

/// The same rule `getSoloVsBuddyCount` applies, per dive.
String? _focusBuddyKey({
  required bool hasLinked,
  required String? text,
  required bool isSolo,
}) {
  if (hasLinked || LegacyNameParser.parse(text).isNotEmpty) return 'buddy';
  return isSolo ? 'solo' : null;
}
