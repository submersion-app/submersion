import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Unified card showing every cylinder on a dive: identity (name, gas mix,
/// volume), start/end pressures, MOD/MND, and per-tank SAC and RMV.
///
/// Replaces the former Tanks card and SAC by Cylinder block. Occupies the
/// [DiveDetailSectionId.tanks] slot on the dive detail page. Per-tank SAC
/// is shown whenever it is computable, regardless of tank count; the
/// consumption row is omitted entirely when it is not.
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
    // Serials with a registry entry get a plain caption; the rest get an
    // Assign chip (issue #1365). Read through `.value`, which keeps the
    // previous list while a diver change reloads the provider; `valueOrNull`
    // would drop to an empty registry and flash the chip for every tank.
    final knownSerials = Transmitter.knownSerials(
      ref.watch(transmittersProvider).value ?? const <Transmitter>[],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_cylinders,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            ...dive.tanks.asMap().entries.map(
              (entry) => _tankRow(
                context,
                index: entry.key,
                tank: entry.value,
                cylinderSac: sacByTankId[entry.value.id],
                tankPressures: tankPressures,
                sourceName: showSourceBadges && entry.value.computerId != null
                    ? computerNames[entry.value.computerId]
                    : null,
                knownSerials: knownSerials,
              ),
            ),
            if (_canReassign(dive, tankPressures))
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.swap_vert),
                  label: Text(context.l10n.diveLog_tank_reassignSeries),
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
  }) {
    final theme = Theme.of(context);
    final serial = normalizeTransmitterSerial(tank.transmitterSerial);
    final serialKnown = serial != null && knownSerials.contains(serial);

    final pressures = _resolveTankPressures(
      tank: tank,
      tankPressures: tankPressures,
    );
    final startP = units.formatPressureValue(pressures.$1);
    final endP = units.formatPressureValue(pressures.$2);
    final pressureUsed = pressures.$1 != null && pressures.$2 != null
        ? pressures.$1! - pressures.$2!
        : null;
    // The pressure drop and the gas volume are one fact in two units, so
    // they read together on one line.
    final gasUsedLiters = cylinderSac?.gasUsedLiters;
    final volumeUsed = gasUsedLiters != null
        ? ' / ${units.convertVolume(gasUsedLiters).round()} '
              '${units.volumeSymbol}'
        : '';
    final used = pressureUsed != null && pressureUsed > 0
        ? ' ${context.l10n.diveLog_tank_gasUsed('${units.formatPressure(pressureUsed)}$volumeUsed')}'
        : '';

    // Preset display name, falling back to formatted volume.
    final preset = tank.presetName != null
        ? TankPresets.byName(tank.presetName!)
        : null;
    final tankLabel =
        preset?.displayName ??
        (tank.volume != null
            ? units.formatTankVolume(
                tank.volume,
                tank.workingPressure,
                cuftDecimals: 1,
              )
            : null);
    final tankTitle = tank.name != null && tank.name!.isNotEmpty
        ? tank.name!
        : context.l10n.diveLog_tank_title(index + 1);

    final workingPpO2 = settings.ppO2MaxWorking;
    final modDepth = units.formatDepth(
      tank.gasMix.mod(ppO2: workingPpO2),
      decimals: 0,
    );
    final mndValue = tank.gasMix.mnd(
      endLimit: settings.endLimit,
      o2Narcotic: settings.o2Narcotic,
    );
    final mndDepth = mndValue.isFinite
        ? units.formatDepth(mndValue, decimals: 0)
        : '--';
    final modMndText = context.l10n.diveLog_tank_modMndInfo(
      modDepth,
      formatFixedForDisplay(workingPpO2, 1),
      mndDepth,
    );
    final consumptionRow = _consumptionRow(
      context.l10n,
      theme,
      cylinderSac,
      sourceName,
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(MdiIcons.divingScubaTank),
      // The trailing rates take their width first, so on a narrow card
      // (a phone, or half of a paired row) the chip drops under the name
      // rather than overflowing beside it.
      title: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$tankTitle (${tank.gasMix.name})'),
          if (tankLabel != null) _volumeChip(theme, tankLabel),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$startP ${units.pressureSymbol} → '
            '$endP ${units.pressureSymbol}$used',
          ),
          ?consumptionRow,
          Text(
            modMndText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
          if (serial != null)
            Row(
              children: [
                Text(
                  context.l10n.transmitters_serial(serial),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!serialKnown) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(context.l10n.diveLog_tank_assignTransmitter),
                    onPressed: () => context.push(
                      Uri(
                        path: '/transmitters/new',
                        queryParameters: {'serial': serial},
                      ).toString(),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      // Either extra subtitle row makes the tile tall, and M3 centres the
      // leading icon on a tall two-line tile, away from the name.
      isThreeLine: serial != null || consumptionRow != null,
      trailing: _checkInButton(tank),
    );
  }

  /// A cylinder that is a gear item (the registry wrote its equipment link)
  /// gets the check-in button; any other cylinder has no trailing widget.
  /// Trailing holds only this fixed-width icon button: ListTile lays trailing
  /// out first and gives the title what is left, so anything carrying text
  /// there starves the tank name on a narrow card (#935). The item loads
  /// through its own provider so the row never blocks on it.
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

  /// Small outlined chip carrying the preset/volume label (e.g. "AL80").
  Widget _volumeChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Subtitle row under the pressure line: attribution badge and one
  /// consumption item per visible lane, wrapping onto a second line when the
  /// card is too narrow for them side by side. Returns null when there is
  /// nothing to show.
  Widget? _consumptionRow(
    AppLocalizations l10n,
    ThemeData theme,
    CylinderSac? cylinderSac,
    String? sourceName,
  ) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );
    final children = [
      if (sourceName != null) FieldAttributionBadge(sourceName: sourceName),
      if (cylinderSac != null && cylinderSac.hasValidSac)
        for (final line in _consumptionLines(l10n, cylinderSac))
          Text(line, style: style),
    ];
    if (children.isEmpty) return null;
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  /// One labeled line per lane the diver displays. RMV needs this
  /// cylinder's own volume; without one the RMV line is omitted here (the
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
  /// time-series fills any nulls.
  (double?, double?) _resolveTankPressures({
    required DiveTank tank,
    required Map<String, List<TankPressurePoint>>? tankPressures,
  }) {
    if (tankPressures != null && tankPressures.containsKey(tank.id)) {
      final points = tankPressures[tank.id]!;
      if (points.isNotEmpty) {
        return (
          tank.startPressure ?? points.first.pressure,
          tank.endPressure ?? points.last.pressure,
        );
      }
    }
    return (tank.startPressure, tank.endPressure);
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
