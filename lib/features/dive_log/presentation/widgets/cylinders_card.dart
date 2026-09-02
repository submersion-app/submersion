import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Unified card showing every cylinder on a dive: identity (name, gas mix,
/// volume), start/end pressures, MOD/MND, and per-tank SAC and RMV.
///
/// Replaces the former Tanks card and SAC by Cylinder block. Occupies the
/// [DiveDetailSectionId.tanks] slot on the dive detail page. Per-tank SAC
/// is shown whenever it is computable, regardless of tank count; the
/// trailing block is omitted entirely when it is not.
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tankRow(
    BuildContext context, {
    required int index,
    required DiveTank tank,
    required CylinderSac? cylinderSac,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required String? sourceName,
  }) {
    final theme = Theme.of(context);

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
    // they read together. It also keeps the trailing slot to the rates:
    // ListTile caps leading and trailing at 56px minus the density
    // adjustment, which is 48px on desktop, and three lines do not fit.
    final gasUsedLiters = cylinderSac?.gasUsedLiters;
    final volumeUsed = gasUsedLiters != null
        ? ' / ${units.convertVolume(gasUsedLiters).round()} '
              '${units.volumeSymbol}'
        : '';
    final used = pressureUsed != null && pressureUsed > 0
        ? ' (${units.formatPressure(pressureUsed)}$volumeUsed used)'
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

    final modDepth = units.formatDepth(tank.gasMix.mod(), decimals: 0);
    final mndValue = tank.gasMix.mnd(
      endLimit: settings.endLimit,
      o2Narcotic: settings.o2Narcotic,
    );
    final mndDepth = mndValue.isFinite
        ? units.formatDepth(mndValue, decimals: 0)
        : '--';
    final modMndText = context.l10n.diveLog_tank_modMndInfo(modDepth, mndDepth);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(MdiIcons.divingScubaTank),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text('$tankTitle (${tank.gasMix.name})')),
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
          Text(
            modMndText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
      ),
      trailing: _trailingBlock(context.l10n, theme, cylinderSac, sourceName),
    );
  }

  /// Small outlined chip carrying the preset/volume label (e.g. "AL80").
  Widget _volumeChip(ThemeData theme, String label) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
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

  /// Trailing column: attribution badge and one consumption line per
  /// visible lane. Returns null when there is nothing to show so the tile
  /// keeps its natural width. The gas used lives in the subtitle, beside
  /// the pressure drop it restates: ListTile caps this slot at two lines on
  /// desktop, and Both already needs both of them.
  Widget? _trailingBlock(
    AppLocalizations l10n,
    ThemeData theme,
    CylinderSac? cylinderSac,
    String? sourceName,
  ) {
    final hasSac = cylinderSac != null && cylinderSac.hasValidSac;
    if (!hasSac && sourceName == null) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (sourceName != null) FieldAttributionBadge(sourceName: sourceName),
        if (hasSac) ...[
          for (final line in _consumptionLines(l10n, cylinderSac))
            Text(
              line,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ],
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
