import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/avelo_summary.dart';
import 'package:submersion/features/dive_log/domain/services/hydrotank_contents.dart';
import 'package:submersion/features/dive_log/domain/services/logged_tank_mod.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_lookup.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/dive_log/presentation/info/cylinders_info.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/avelo_summary_block.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinder_block.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_series_exchange.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_cursor_line.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_gear_menu.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_fill_levels.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_labels.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

/// Unified card showing every cylinder on a dive: each tank drawn as a
/// figure filled to show the gas left and the gas used, labelled with its
/// start, end and used pressures (issue #3773), beside what the tank is, its
/// gas, and a quiet detail block (gas used, loop use on a CCR dive, SAC and
/// RMV, MOD/MND, trip cylinder, transmitter, check-in). Issue #3675 had first
/// made the stack of differently styled lines a table.
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
  final UnitFormatterSettings settings;
  final GasConsumptionDisplay display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // With unlock-to-edit offered (issue #4527) nothing here writes while
    // the dive is locked: Reassign moves into the open card, a check-in
    // waits for the unlock, and Assign, which links this and other dives'
    // cylinders at once, shows only in a sitting with nothing unsaved.
    final edit = RecordEditScope.of<Dive>(context);
    final sitting = edit.session;
    // `.value`, not `valueOrNull`, here and below: a reload keeps what is
    // already shown rather than dropping it from every row. In a sitting a
    // held reassign has moved the readings: each cylinder is drawn with
    // what it holds then, as its pressures already are.
    final storedPressures = ref.watch(tankPressuresProvider(dive.id)).value;
    final tankPressures = sitting == null
        ? storedPressures
        : tankReadingsInSitting(sitting, storedPressures);
    // Each tank's own series, matched as everywhere else when it is still
    // keyed by an old tank id (#276), so the figure's Start and End read the
    // same series as its cursor line.
    final seriesByTank = resolveTankPressureSeries(dive.tanks, tankPressures);
    final cylinderSacs =
        ref.watch(cylinderSacProvider(dive.id)).value ?? const <CylinderSac>[];
    final sacByTankId = {for (final c in cylinderSacs) c.tankId: c};
    // The pressure lines the profile chart draws, for the tank figures to
    // read at its cursor (issue #4291). Always watched, so a figure keeps
    // room for its cursor label before the cursor arrives.
    final cursorLines = TankCursorLine.forTanks(
      dive.tanks,
      _chartSeriesInSitting(sitting, watchChartTankSeries(ref, dive.id)),
    );
    final dataSources =
        ref.watch(diveDataSourcesProvider(dive.id)).value ??
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
    // Assign, the cylinder menu and a check-in each write at once: whole-
    // record operations, listed but disabled until the page is unlocked
    // with nothing to save (issue #4527, plan 7).
    final operationReason = recordOperationReason(
      l10n,
      recordOperationBlockOf(edit),
    );
    final runAsOperation = recordOperationRunnerOf(edit);
    // A check-in is for a cylinder the dive is stored with: one only in the
    // sitting may never be saved.
    final storedGearIds = {
      for (final t in (sitting?.stored ?? dive).tanks) ?t.equipmentId,
    };
    bool checkInReadOnly(DiveTank tank) =>
        !storedGearIds.contains(tank.equipmentId);
    // What the computer recorded in Avelo mode (issue #4664), under the
    // Hydrotank, or under the first tank when none carries that role.
    final aveloTank =
        dive.tanks.where((t) => t.role == TankRole.hydrotank).firstOrNull ??
        dive.tanks.firstOrNull;
    final aveloSummary = aveloTank == null
        ? null
        : aveloSummaryOf(
            dive.profile,
            // Only a Hydrotank's pressure is the Avelo max pressure; under
            // another tank the summary leaves it out.
            aveloTank.role == TankRole.hydrotank
                ? seriesByTank[aveloTank.id]
                : null,
          );
    final rows = [
      for (final entry in dive.tanks.asMap().entries)
        _tankRow(
          context,
          index: entry.key,
          tank: entry.value,
          aveloSummary: entry.value.id == aveloTank?.id ? aveloSummary : null,
          cylinderSac: sacByTankId[entry.value.id],
          cursorLine: cursorLines[entry.value.id],
          series: seriesByTank[entry.value.id],
          sourceName: showSourceBadges && entry.value.computerId != null
              ? computerNames[entry.value.computerId]
              : null,
          knownSerials: knownSerials,
          slotLabel: slotLabels[entry.value.tripCylinderId],
          showRole: showRoles,
          operationReason: operationReason,
          runAsOperation: runAsOperation,
          checkInReadOnly: checkInReadOnly(entry.value),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The shared title row: unlocked, it gains the pencil and the
            // whole row opens the card, without growing.
            RecordCardHeader(
              title: l10n.diveLog_detail_section_cylinders,
              trailing: HeaderInfoButton(
                title: l10n.diveLog_detail_section_cylinders,
                content: (context) => cylindersInfo(
                  context.l10n,
                  infoUnits(context),
                  hasNitrox: dive.tanks.any((t) => t.gasMix.isNitrox),
                  hasTrimix: dive.tanks.any((t) => t.gasMix.isTrimix),
                  isRebreather: dive.isRebreather,
                  hasBreathingGas: dive.breathingTanks.isNotEmpty,
                  showsSac: display.showsSac,
                  showsRmv: display.showsRmv,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
              rows[i],
            ],
            // The ppO2 limits behind the MODs are said once here rather than
            // on each row. A rule closes the table first, so the note reads
            // as the card's, not as a detail of the last cylinder. A dive
            // whose only cylinder is a suit inflation bottle shows no MOD,
            // so it has no note (issue #4243).
            if (rows.isNotEmpty && dive.breathingTanks.isNotEmpty) ...[
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
    // A suit inflation bottle has no MOD, so no limit (issue #4243).
    final inUse = {
      for (final tank in dive.breathingTanks)
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
  static bool canReassignTankSeries(
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

  /// The chart's lines for the figures' cursor labels, moved as [sitting]'s
  /// held reassign moves the readings ([tankReadingsInSitting]), so a figure
  /// reads the same series at the cursor as its start and end.
  static EstimatedTankPressures? _chartSeriesInSitting(
    EditSession<Dive>? sitting,
    EstimatedTankPressures? chart,
  ) {
    if (sitting == null || chart == null) return chart;
    if (heldTankSeriesExchanges(sitting).isEmpty) return chart;
    final estimated = tankReadingsInSitting(sitting, {
      for (final id in chart.estimatedTankIds) id: true,
    })!;
    return EstimatedTankPressures(
      tankReadingsInSitting(sitting, chart.pressures)!,
      estimated.keys.toSet(),
    );
  }

  /// An Avelo Hydrotank's figure as estimated water and gas (issue #4664),
  /// at [cursorSeconds] or, without a cursor, at the end of the dive, with
  /// the water's label when the tank's [volume] is known, or null when
  /// the dive lacks what the estimate needs (a start pressure, a pressure
  /// at the moment shown, or the computer's gas remaining).
  ({TankFillLevels levels, String? label})? _hydrotankWater(
    AppLocalizations l10n, {
    required double? start,
    required double? pressure,
    required int? cursorSeconds,
    required double? volume,
  }) {
    if (start == null || pressure == null) return null;
    final gas = gasRemainingAt(dive.profile, cursorSeconds);
    if (gas == null) return null;
    final contents = hydrotankContents(
      startBar: start,
      nowBar: pressure,
      gasRemainingPercent: gas,
    );
    if (contents == null) return null;
    final liters = volume == null ? null : contents.water * volume;
    return (
      levels: TankFillLevels.hydrotank(
        water: contents.water,
        gasLeft: contents.gasLeft,
        now: cursorSeconds != null ? contents.gasLeft : null,
      ),
      label: liters == null
          ? null
          : l10n.diveLog_cylinders_figureWater(
              units.formatVolume(
                liters,
                decimals: units.settings.volumeUnit == VolumeUnit.liters
                    ? 1
                    : 2,
              ),
            ),
    );
  }

  /// Where the profile cursor is, in seconds into the dive. The cursor is an
  /// index into the chart's own series, so it is resolved against that
  /// series (#543), which is only watched while the cursor is on the chart.
  int? _cursorSeconds(WidgetRef ref) {
    final index = ref.watch(profileTrackingIndexProvider(dive.id));
    if (index == null || index < 0) return null;
    final chartProfile = watchChartProfile(ref, dive);
    return index < chartProfile.length ? chartProfile[index].timestamp : null;
  }

  Widget _tankRow(
    BuildContext context, {
    required int index,
    required DiveTank tank,
    required CylinderSac? cylinderSac,
    required TankCursorLine? cursorLine,
    required List<TankPressurePoint>? series,
    required String? sourceName,
    required Set<String> knownSerials,
    required TripCylinderTankLabel? slotLabel,
    required bool showRole,
    required String? operationReason,
    required RecordOperationRunner runAsOperation,
    required bool checkInReadOnly,
    AveloSummary? aveloSummary,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final serial = normalizeTransmitterSerial(tank.transmitterSerial);
    final serialKnown = serial != null && knownSerials.contains(serial);
    final nameDerivedRole = tank.roleSource == TankRoleSource.transmitterName;

    final pressures = resolvedTankPressures(tank, series);
    final pressureUsed = pressures.$1 != null && pressures.$2 != null
        ? pressures.$1! - pressures.$2!
        : null;
    // A tank carried but not breathed used 0, which is not missing data;
    // only a rise (a sensor or entry error) has no meaningful figure.
    final hasUsed = pressureUsed != null && pressureUsed > 0;
    // An Avelo Hydrotank is breathed, but its pressure rises and falls with
    // the water pumped in for buoyancy (issue #4657): its drop is no gas
    // used, so the card shows its pressures and says why it has no figures.
    final waterDriven = tank.role.isUnmeasuredBreathingGas;

    // Preset display name, falling back to formatted volume.
    final preset = tank.presetName != null
        ? TankPresets.byName(tank.presetName!)
        : null;
    // The figure is full at the tank's rated pressure, so a short fill shows
    // as a tank never quite full; the preset fills in a tank's own gaps. A
    // zero or negative value is "not recorded", not a rating, so it is a gap.
    double? positive(double? value) =>
        value != null && value > 0 ? value : null;
    // Only the figure follows the profile cursor (issue #4291), so only it
    // rebuilds on every hover frame, not the whole card.
    final figure = Consumer(
      builder: (context, ref, _) {
        final cursorSeconds = _cursorSeconds(ref);
        final now = cursorLine?.pressureAt(cursorSeconds);
        String? nowLabel(double? pressure) {
          if (pressure == null) return null;
          final shown = units.formatPressure(pressure);
          return cursorLine!.estimated
              ? l10n.diveLog_cylinders_figureNowEstimated(shown)
              : l10n.diveLog_cylinders_figureNow(shown);
        }

        // An Avelo Hydrotank with gas remaining is drawn as its estimated
        // water and gas (issue #4664), at the cursor or at the end. With the
        // cursor on the chart but no Hydrotank reading there, it keeps the
        // pressure figure rather than showing the end in the cursor's place.
        final cursorShown = cursorSeconds != null;
        final water = waterDriven
            ? _hydrotankWater(
                l10n,
                start: pressures.$1,
                pressure: cursorShown ? now : pressures.$2,
                cursorSeconds: cursorSeconds,
                volume: positive(tank.volume) ?? preset?.volumeLiters,
              )
            : null;
        final figure = TankFigure(
          levels:
              water?.levels ??
              TankFillLevels.resolve(
                start: pressures.$1,
                end: pressures.$2,
                rated:
                    positive(tank.workingPressure) ??
                    preset?.workingPressureBar,
                now: now,
              ),
          gasColor: GasColors.forGasMix(tank.gasMix),
          volumeLiters: positive(tank.volume) ?? preset?.volumeLiters,
          startLabel: l10n.diveLog_cylinders_figureStart(
            units.formatPressure(pressures.$1),
          ),
          endLabel: l10n.diveLog_cylinders_figureEnd(
            units.formatPressure(pressures.$2),
          ),
          usedLabel: !waterDriven && pressureUsed != null && pressureUsed >= 0
              ? l10n.diveLog_cylinders_figureUsed(
                  units.formatPressure(pressureUsed),
                )
              : null,
          markStart: pressures.$1 != null,
          markEnd: pressures.$2 != null,
          nowLabel: nowLabel(now),
          nowLabelReserve: nowLabel(cursorLine?.peak),
        );
        final waterLabel = water?.label;
        if (waterLabel == null) return figure;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            figure,
            Text(
              waterLabel,
              key: Key('tank-water-label-${tank.id}'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
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
    // A suit inflation bottle is listed with its pressures, but it is not
    // breathed: no gas used, loop use, SAC, MOD or MND (issue #4243). The
    // rows can be the provider's retained value from before the tank became
    // a suit bottle, so the role gates every figure, not just the fresh ones.
    final breathing = tank.role.isBreathingGas;

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
            if (breathing && !waterDriven && hasUsed && gasUsedLiters != null)
              Text(
                l10n.diveLog_cylinders_gasUsed(
                  '${units.convertVolume(gasUsedLiters).round()} '
                  '${units.volumeSymbol}',
                ),
              ),
            if (breathing && !waterDriven)
              if (cylinderSac?.loopRate case final loopRate?)
                Text(
                  key: Key('tank-loop-use-${tank.id}'),
                  l10n.diveLog_cylinders_loopUse(units.formatRmv(loopRate)),
                ),
            if (breathing &&
                !waterDriven &&
                cylinderSac != null &&
                cylinderSac.hasValidSac)
              for (final line in _consumptionLines(l10n, cylinderSac))
                Text(line),
            if (breathing) ...[
              Text(l10n.diveLog_cylinders_mod(modDepth)),
              Text(l10n.diveLog_cylinders_mnd(mndDepth)),
            ],
          ],
        ),
        if (waterDriven)
          Text(
            l10n.diveLog_cylinders_hydrotankNote,
            key: Key('tank-hydrotank-note-${tank.id}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (aveloSummary != null)
          AveloSummaryBlock(
            key: Key('tank-avelo-summary-${tank.id}'),
            summary: aveloSummary,
            units: units,
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
              // A whole-record operation: shown at every lock state, so
              // the line is the same height locked and unlocked, disabled
              // with its reason until it may run (issue #4527, plan 7).
              if (!serialKnown)
                RecordOperationButton(
                  reason: operationReason,
                  onPressed: () {
                    void assign() => context.push(
                      Uri(
                        path: '/transmitters/new',
                        // The dive lets an unregistered serial get its item.
                        queryParameters: {'serial': serial, 'dive': dive.id},
                      ).toString(),
                    );
                    // The setup page replaces itself on the way, so its
                    // answer is not awaited: the sitting starts again at
                    // once and follows the rows the setup links.
                    runAsOperation(() async {
                      assign();
                      return true;
                    });
                  },
                  builder: (onPressed) => TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.labelMedium,
                    ),
                    onPressed: onPressed,
                    child: Text(l10n.diveLog_tank_assignTransmitter),
                  ),
                ),
            ],
          ),
      ],
      trailing: _trailing(
        tank,
        checkInReadOnly: checkInReadOnly,
        operationReason: operationReason,
        runAsOperation: runAsOperation,
      ),
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

  /// The check-in of a linked cylinder, then the tank's cylinder menu
  /// (issue #4494). The menu writes at once, so like Assign it shows only
  /// where [canAssign] allows; its room is kept while hidden, so the row is
  /// the same width locked and unlocked.
  Widget _trailing(
    DiveTank tank, {
    required bool checkInReadOnly,
    required String? operationReason,
    required RecordOperationRunner runAsOperation,
  }) {
    final checkIn = _checkInButton(
      tank,
      readOnly: checkInReadOnly,
      operationReason: operationReason,
      runAsOperation: runAsOperation,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?checkIn,
        TankGearMenu(
          dive: dive,
          tank: tank,
          operationReason: operationReason,
          runAsOperation: runAsOperation,
        ),
      ],
    );
  }

  /// A cylinder that is a gear item (the registry wrote its equipment link)
  /// gets the check-in button at the end of its detail block; any other
  /// cylinder has none. The item loads through its own provider so the row
  /// never blocks on it.
  Widget? _checkInButton(
    DiveTank tank, {
    required bool readOnly,
    required String? operationReason,
    required RecordOperationRunner runAsOperation,
  }) {
    final equipmentId = tank.equipmentId;
    if (equipmentId == null) return null;
    return Consumer(
      builder: (context, ref, _) {
        final item = ref.watch(equipmentItemProvider(equipmentId)).value;
        if (item == null) return const SizedBox.shrink();
        return ObservationStatusChip(
          equipment: item,
          dive: dive,
          readOnly: readOnly,
          operationReason: readOnly ? null : operationReason,
          runAsOperation: runAsOperation,
        );
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
