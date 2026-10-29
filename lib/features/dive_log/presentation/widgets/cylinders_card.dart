import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/logged_tank_mod.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinder_block.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_fill_levels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_labels.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Unified card showing every cylinder on a dive: each tank drawn as a
/// figure filled to show the gas left and the gas used, labelled with its
/// start, end and used pressures (issue #3773), beside what the tank is, its
/// gas, and a quiet detail block (gas used, SAC and RMV, MOD/MND, trip
/// cylinder, transmitter, check-in). Issue #3675 had first made the stack of
/// differently styled lines a table.
///
/// Replaces the former Tanks card and SAC by Cylinder block. Occupies the
/// [DiveDetailSectionId.tanks] slot on the dive detail page. Per-tank SAC
/// is shown whenever it is computable, regardless of tank count; it is
/// omitted when it is not.
class CylindersCard extends ConsumerWidget {
  const CylindersCard({
    super.key,
    required this.dive,
    required this.units,
    required this.settings,
    required this.display,
  });

  final Dive dive;
  final UnitFormatter units;
  final AppSettings settings;
  final GasConsumptionDisplay display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tankPressures = ref.watch(tankPressuresProvider(dive.id)).valueOrNull;
    final cylinderSacs =
        ref.watch(cylinderSacProvider(dive.id)).valueOrNull ??
        const <CylinderSac>[];
    final sacByTankId = {for (final c in cylinderSacs) c.tankId: c};
    final dataSources =
        ref.watch(diveDataSourcesProvider(dive.id)).valueOrNull ??
        const <DiveDataSource>[];
    // Only badge tanks once there's more than one source to disambiguate —
    // a single-source dive never needs attribution.
    final showSourceBadges = dataSources.length >= 2;
    final computerNames = _computerDisplayNames(context, dataSources);
    // Serials of a transmitter that is set up get a plain caption; the rest
    // get an Assign button (issue #1365). Set up, not merely registered: a
    // download registers every serial it sees (issue #3676). Read through
    // `.value`, which keeps the previous list while a diver change reloads
    // the provider; `valueOrNull` would drop to an empty registry and flash
    // the button for every tank.
    final knownSerials = Transmitter.setUpSerials(
      ref.watch(transmittersProvider).value ?? const <Transmitter>[],
    );
    // Linked tanks name their trip cylinder and the bottle it held when the
    // dive started (decided 2026-09-28). Only read when a tank is linked.
    final tripId = dive.tripId ?? dive.trip?.id;
    final slotLabels =
        tripId == null || !dive.tanks.any((t) => t.tripCylinderId != null)
        ? const <String, TripCylinderTankLabel>{}
        : ref
                  .watch(
                    tripCylinderLabelsAtProvider((
                      tripId: tripId,
                      atMillis: dive.effectiveEntryTime.millisecondsSinceEpoch,
                    )),
                  )
                  .value ??
              const <String, TripCylinderTankLabel>{};
    // Every tank names its role (issue #2901) except the default single
    // back-gas cylinder of most dives, where the label says nothing new.
    final showRoles =
        dive.tanks.length != 1 || dive.tanks.single.role != TankRole.backGas;

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rows = [
      for (final entry in dive.tanks.asMap().entries)
        _tankRow(
          context,
          index: entry.key,
          tank: entry.value,
          cylinderSac: sacByTankId[entry.value.id],
          tankPressures: tankPressures,
          sourceName: showSourceBadges && entry.value.computerId != null
              ? computerNames[entry.value.computerId]
              : null,
          knownSerials: knownSerials,
          slotLabel: slotLabels[entry.value.tripCylinderId],
          showRole: showRoles,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveLog_detail_section_cylinders,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
              rows[i],
            ],
            // The ppO2 limits behind the MODs are said once here rather than
            // on each row. A rule closes the table first, so the note reads
            // as the card's, not as a detail of the last cylinder.
            if (rows.isNotEmpty) ...[
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.diveLog_cylinders_modNote(_modLimitsNote(l10n)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (_canReassign(dive, tankPressures))
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.swap_vert),
                  label: Text(l10n.diveLog_tank_reassignSeries),
                  onPressed: () => showTankSeriesReassignSheet(
                    context,
                    ref,
                    dive: dive,
                    tankPressures: tankPressures ?? const {},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The diver's ppO2 for [limit]. A cylinder's MOD is taken at the limit
  /// its role calls for on this dive (issue #3752), not always the bottom
  /// one.
  double _modPpO2(ModLimitClass limit) => modLimitPpO2(
    limit,
    bottomPpO2: settings.ppO2MaxWorking,
    decoPpO2: settings.ppO2MaxDeco,
    diluentPpO2: settings.ccrDiluentModPpO2,
  );

  /// What the MOD note says the card's MODs are taken at. One ppO2 when
  /// every cylinder's limit has the same value, even two limits that
  /// share it (the default deco and Dil MOD limits are both 1.6), as the
  /// card always said. Otherwise each limit in use with its ppO2, bottom
  /// first: "1.4 (bottom limit), 1.6 (deco limit)".
  String _modLimitsNote(AppLocalizations l10n) {
    final inUse = {
      for (final tank in dive.tanks)
        loggedTankModLimit(tank.role, tank.gasMix, dive.diveMode),
    };
    final limits = [
      for (final limit in const [
        ModLimitClass.bottom,
        ModLimitClass.deco,
        ModLimitClass.diluent,
      ])
        if (inUse.contains(limit)) limit,
    ];
    // Compared as shown: two values that round alike read as one ppO2.
    final shown = {
      for (final limit in limits)
        limit: formatFixedForDisplay(_modPpO2(limit), 1),
    };
    if (shown.values.toSet().length == 1) return shown.values.first;
    return [
      for (final limit in limits)
        l10n.diveLog_cylinders_modLimit(shown[limit]!, switch (limit) {
          ModLimitClass.bottom => l10n.tankMod_limitBottom,
          ModLimitClass.deco => l10n.tankMod_limitDeco,
          ModLimitClass.diluent => l10n.tankMod_limitDiluent,
        }),
    ].join(l10n.diveLog_cylinders_modLimitSeparator);
  }

  /// Two or more of this dive's tanks carry a series from one computer
  /// (issue #1314): only then is there anything to move.
  static bool _canReassign(
    Dive dive,
    Map<String, List<TankPressurePoint>>? tankPressures,
  ) {
    if (tankPressures == null) return false;
    final byComputer = <String?, int>{};
    for (final tank in dive.tanks) {
      if ((tankPressures[tank.id] ?? const []).isEmpty) continue;
      byComputer[tank.computerId] = (byComputer[tank.computerId] ?? 0) + 1;
    }
    return byComputer.values.any((n) => n >= 2);
  }

  Widget _tankRow(
    BuildContext context, {
    required int index,
    required DiveTank tank,
    required CylinderSac? cylinderSac,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required String? sourceName,
    required Set<String> knownSerials,
    required TripCylinderTankLabel? slotLabel,
    required bool showRole,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final serial = normalizeTransmitterSerial(tank.transmitterSerial);
    final serialKnown = serial != null && knownSerials.contains(serial);
    final nameDerivedRole = tank.roleSource == TankRoleSource.transmitterName;

    final pressures = _resolveTankPressures(
      tank: tank,
      tankPressures: tankPressures,
    );
    final pressureUsed = pressures.$1 != null && pressures.$2 != null
        ? pressures.$1! - pressures.$2!
        : null;
    // A tank carried but not breathed used 0, which is not missing data;
    // only a rise (a sensor or entry error) has no meaningful figure.
    final hasUsed = pressureUsed != null && pressureUsed > 0;

    // Preset display name, falling back to formatted volume.
    final preset = tank.presetName != null
        ? TankPresets.byName(tank.presetName!)
        : null;
    // The figure is full at the tank's rated pressure, so a short fill shows
    // as a tank never quite full; the preset fills in a tank's own gaps. A
    // zero or negative value is "not recorded", not a rating, so it is a gap.
    double? positive(double? value) =>
        value != null && value > 0 ? value : null;
    final figure = TankFigure(
      levels: TankFillLevels.resolve(
        start: pressures.$1,
        end: pressures.$2,
        rated: positive(tank.workingPressure) ?? preset?.workingPressureBar,
      ),
      gasColor: GasColors.forGasMix(tank.gasMix),
      volumeLiters: positive(tank.volume) ?? preset?.volumeLiters,
      startLabel: l10n.diveLog_cylinders_figureStart(
        units.formatPressure(pressures.$1),
      ),
      endLabel: l10n.diveLog_cylinders_figureEnd(
        units.formatPressure(pressures.$2),
      ),
      usedLabel: pressureUsed != null && pressureUsed >= 0
          ? l10n.diveLog_cylinders_figureUsed(
              units.formatPressure(pressureUsed),
            )
          : null,
      markStart: pressures.$1 != null,
      markEnd: pressures.$2 != null,
    );
    final sizeLabel =
        preset?.displayName ??
        (tank.volume != null
            ? units.formatTankVolume(
                tank.volume,
                tank.workingPressure,
                cuftDecimals: 1,
              )
            : null);
    final hasName = tank.name != null && tank.name!.isNotEmpty;
    // A named tank keeps its size under the name; otherwise the size is
    // what the diver knows the tank by.
    final title = hasName
        ? tank.name!
        : sizeLabel ?? l10n.diveLog_tank_title(index + 1);

    final modDepth = units.formatDepthFloor(
      tank.gasMix.mod(
        ppO2: _modPpO2(
          loggedTankModLimit(tank.role, tank.gasMix, dive.diveMode),
        ),
      ),
      decimals: 0,
    );
    final mndValue = tank.gasMix.mnd(
      endLimit: settings.endLimit,
      o2Narcotic: settings.o2Narcotic,
    );
    final mndDepth = mndValue.isFinite
        ? units.formatDepthFloor(mndValue, decimals: 0)
        : '--';
    // The pressure drop and the gas volume are one fact in two units; the
    // volume opens the detail line (after the source badge, when shown).
    final gasUsedLiters = cylinderSac?.gasUsedLiters;

    return CylinderBlock(
      figure: figure,
      icon: tank.role.icon,
      title: title,
      subtitle: [
        if (hasName && sizeLabel != null) Text(sizeLabel),
        if (showRole)
          KeyedSubtree(
            key: Key('tank-role-${tank.id}'),
            child: Text(tank.role.localizedName(l10n)),
          ),
      ],
      gasMix: tank.gasMix,
      gasLabel: l10n.diveLog_cylinders_gasSemantics(tank.gasMix.name),
      details: [
        DotJoinedWrap(
          children: [
            if (sourceName != null)
              FieldAttributionBadge(sourceName: sourceName),
            if (hasUsed && gasUsedLiters != null)
              Text(
                l10n.diveLog_cylinders_gasUsed(
                  '${units.convertVolume(gasUsedLiters).round()} '
                  '${units.volumeSymbol}',
                ),
              ),
            if (cylinderSac != null && cylinderSac.hasValidSac)
              for (final line in _consumptionLines(l10n, cylinderSac))
                Text(line),
            Text(l10n.diveLog_cylinders_mod(modDepth)),
            Text(l10n.diveLog_cylinders_mnd(mndDepth)),
          ],
        ),
        if (slotLabel != null)
          Text(
            tripCylinderTankLine(l10n, slotLabel),
            key: Key('tank-trip-cylinder-${tank.id}'),
          ),
        if (nameDerivedRole) _roleFromTransmitterNameLine(context, tank),
        if (serial != null)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.transmitters_serial(serial)),
              if (!serialKnown)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  onPressed: () => context.push(
                    Uri(
                      path: '/transmitters/new',
                      // The dive lets an unregistered serial get its item.
                      queryParameters: {'serial': serial, 'dive': dive.id},
                    ).toString(),
                  ),
                  child: Text(l10n.diveLog_tank_assignTransmitter),
                ),
            ],
          ),
      ],
      trailing: _checkInButton(tank),
    );
  }

  /// The cylinder's role, marked as the computer's reading of the
  /// transmitter's name (issue #2595). On a rebreather a bailout named "OC"
  /// becomes the oxygen supply that way, and every ppO2 figure downstream
  /// follows the role, so the diver is shown it is unconfirmed. Assigning
  /// the transmitter (the button on the serial line) settles it. It keeps
  /// the error colour: it is a warning, not one of the quiet details.
  Widget _roleFromTransmitterNameLine(BuildContext context, DiveTank tank) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Row(
      key: Key('tank-role-from-transmitter-name-${tank.id}'),
      children: [
        Icon(Icons.help_outline, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.l10n.diveLog_tank_roleFromTransmitterName(
              tank.role.localizedName(context.l10n),
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  /// A cylinder that is a gear item (the registry wrote its equipment link)
  /// gets the check-in button at the end of its detail block; any other
  /// cylinder has none. The item loads through its own provider so the row
  /// never blocks on it.
  Widget? _checkInButton(DiveTank tank) {
    final equipmentId = tank.equipmentId;
    if (equipmentId == null) return null;
    return Consumer(
      builder: (context, ref, _) {
        final item = ref.watch(equipmentItemProvider(equipmentId)).value;
        if (item == null) return const SizedBox.shrink();
        return ObservationStatusChip(equipment: item, dive: dive);
      },
    );
  }

  /// One labeled item per lane the diver displays. RMV needs this
  /// cylinder's own volume; without one the RMV item is omitted here (the
  /// summary row carries the volume hint, not every cylinder). Only called
  /// when [CylinderSac.hasValidSac] is true.
  List<String> _consumptionLines(AppLocalizations l10n, CylinderSac cylinder) {
    final rmv = cylinder.rmv;
    return [
      if (display.showsSac)
        '${l10n.gasConsumption_sac} ${units.formatSac(cylinder.sacRate!)}',
      if (display.showsRmv && rmv != null)
        '${l10n.gasConsumption_rmv} ${units.formatRmv(rmv)}',
    ];
  }

  /// Resolves start/end pressure: stored tank metadata wins, per-tank
  /// time-series fills any nulls. A negative reading is a sensor or entry
  /// error, never a pressure, so it counts as missing: no figure level and
  /// no used amount is drawn from it.
  (double?, double?) _resolveTankPressures({
    required DiveTank tank,
    required Map<String, List<TankPressurePoint>>? tankPressures,
  }) {
    double? valid(double? pressure) =>
        pressure != null && pressure >= 0 ? pressure : null;
    final start = valid(tank.startPressure);
    final end = valid(tank.endPressure);
    final points = tankPressures?[tank.id];
    if (points != null && points.isNotEmpty) {
      return (
        start ?? valid(points.first.pressure),
        end ?? valid(points.last.pressure),
      );
    }
    return (start, end);
  }

  /// computerId -> display name via the shared source-name resolver.
  Map<String, String> _computerDisplayNames(
    BuildContext context,
    List<DiveDataSource> dataSources,
  ) {
    final labels = SourceNameLabels(
      unknownComputer: context.l10n.diveLog_sources_unknownComputer,
      manualEntry: context.l10n.diveLog_sources_manualEntry,
      importedFile: context.l10n.diveLog_sources_importedFile,
      editedSuffix: context.l10n.diveLog_sources_editedSuffix,
    );
    return {
      for (final source in dataSources)
        if (source.computerId != null)
          source.computerId!: resolveSourceName(source, labels),
    };
  }
}
