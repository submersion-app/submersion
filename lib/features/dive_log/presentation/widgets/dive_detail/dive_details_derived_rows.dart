import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/elapsed_duration_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_text_section.dart';
import 'package:submersion/features/dive_computer/presentation/navigation/dive_computer_location.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/helpers/source_name_labels.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_volume_hint.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';

/// What the Details card says about a dive left out of statistics, or null
/// for a dive that is counted. The master switch wins: it already implies
/// the gas one, so naming both would read as two separate settings.
String? diveStatisticsExclusion(AppLocalizations l10n, Dive dive) {
  if (dive.excludedFromStats) return l10n.diveLog_edit_summary_excluded;
  if (dive.excludedFromGasStats) return l10n.diveLog_edit_summary_gasExcluded;
  return null;
}

/// A Details row that leads somewhere: the label, then the linked item's
/// name (and an optional second line) with a chevron right beside it. The
/// caller supplies the tap.
class DiveDetailLinkRow extends StatelessWidget {
  const DiveDetailLinkRow({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final String label;
  final String title;
  final String? subtitle;

  /// Drawn before the title, such as a dive center's logo (#4460).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return DetailRow(
      label: label,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          ExcludeSemantics(
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rows of the Details card that nothing on the card edits, in the
/// card's order: the buddy and dive master as imported text, air
/// consumption, gradient factors, the dive computer and the surface
/// interval.
///
/// The read card ends with them, and so does the card's editor, so that
/// nothing the card showed disappears when it opens.
class DiveDetailsDerivedRows extends ConsumerWidget {
  const DiveDetailsDerivedRows({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final showBadgesSetting = ref.watch(
      settingsProvider.select((s) => s.showDataSourceBadges),
    );
    final viewedSourceId = ref.watch(activeDiveSourceProvider(dive.id));
    final dataSources = watchDiveDataSources(ref, dive.id);
    final computedAttribution = FieldAttributionService.computeAttribution(
      dataSources,
      viewedSourceId: viewedSourceId,
      nameOf: (s) => resolveSourceName(s, sourceNameLabelsFor(context)),
    );
    final showBadges = showBadgesSetting && computedAttribution.isNotEmpty;
    final attribution = showBadges ? computedAttribution : null;
    // The Dive Computer row follows the active source.
    final activeSource = viewedSourceId == null
        ? dataSources.where((s) => s.isPrimary).firstOrNull
        : dataSources.where((s) => s.id == viewedSourceId).firstOrNull;
    final activeComputerId = activeSource?.computerId;

    final surfaceIntervalAsync = ref.watch(surfaceIntervalProvider(dive.id));
    // The legacy free-text buddy and dive master columns are only a fallback
    // while the dive_buddies junction is empty, the same rule as the Buddies
    // card, the dive list and the exports (#1864). Otherwise an imported
    // name the diver has since replaced keeps showing here (#3581). Shown
    // only once the junction has been read as empty, so neither the first
    // load nor a failed one can bring a stale name back. A refresh keeps the
    // last answer until the new one arrives, as the Buddies card does, so
    // the rows do not flicker on every unrelated change to the dive.
    final showLegacyText = ref.watch(
      buddiesForDiveProvider(
        dive.id,
      ).select((a) => a.valueOrNull?.isEmpty ?? false),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A placeholder such as "None" is no one, as on the Buddies card.
        if (showLegacyText && LegacyBuddyTextSection.hasBuddyText(dive))
          DiveDetailRow(
            label: context.l10n.diveLog_detail_label_buddy,
            value: dive.buddy!.trim(),
          ),
        if (showLegacyText && LegacyBuddyTextSection.hasDiveMasterText(dive))
          DiveDetailRow(
            label: context.l10n.diveLog_detail_label_diveMaster,
            value: dive.diveMaster!.trim(),
          ),
        _buildGasConsumptionRows(context, ref, units),
        // Gradient factors (from dive computer)
        if (dive.gradientFactorLow != null && dive.gradientFactorHigh != null)
          DiveDetailRow(
            label: context.l10n.diveLog_detail_label_gradientFactors,
            value: 'GF ${dive.gradientFactorLow}/${dive.gradientFactorHigh}',
          ),
        // Dive computer info (from profile link or string fields)
        ..._buildDiveComputerRows(
          context,
          ref,
          activeComputerId: activeComputerId,
        ),
        // Surface interval: prefer imported value, fall back to calculated
        if (dive.surfaceInterval != null)
          DiveDetailRow(
            label: context.l10n.diveLog_detail_label_surfaceInterval,
            value: formatElapsed(context.l10n, dive.surfaceInterval!),
            sourceName: attribution?['surfaceInterval'],
          )
        else
          surfaceIntervalAsync.when(
            data: (interval) {
              if (interval == null) return const SizedBox.shrink();
              return DiveDetailRow(
                label: context.l10n.diveLog_detail_label_surfaceInterval,
                value: formatElapsed(context.l10n, interval),
                sourceName: attribution?['surfaceInterval'],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }

  /// The consumption rows of the summary: SAC (pressure lane) and RMV
  /// (volume lane) behind the diver's display preference. A lane that
  /// cannot be computed is omitted. A wanted-but-missing RMV shows the
  /// volume hint instead of vanishing (issue #386), and RMV-only mode falls
  /// back to the SAC row so the diver still sees a number.
  Widget _buildGasConsumptionRows(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final display = ref.watch(gasConsumptionDisplayProvider);
    final sac = dive.sac;
    final rmv = display.showsRmv
        ? dive.rmvFor(ref.watch(gasModelProvider))
        : null;
    final l10n = context.l10n;

    Widget sacRow() => DiveDetailRow(
      label: l10n.diveLog_detail_label_sac,
      value: units.formatSac(sac!),
    );

    final rows = <Widget>[
      if (display.showsSac && sac != null) sacRow(),
      if (rmv != null)
        DiveDetailRow(
          label: l10n.diveLog_detail_label_rmv,
          value: units.formatRmv(rmv),
        ),
      if (display.showsRmv && rmv == null && sac != null) ...[
        if (!display.showsSac) sacRow(),
        DiveVolumeHint(volumeSymbol: units.volumeSymbol),
      ],
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  /// Build dive computer rows from profile-linked computers or string fields.
  List<Widget> _buildDiveComputerRows(
    BuildContext context,
    WidgetRef ref, {
    String? activeComputerId,
  }) {
    final computersAsync = ref.watch(computersForDiveProvider(dive.id));

    return computersAsync.when(
      data: (computers) {
        if (computers.isNotEmpty) {
          // Show the active source's computer when one is selected; fall
          // back to the first linked computer.
          final active = activeComputerId == null
              ? null
              : computers.where((c) => c.id == activeComputerId).firstOrNull;
          return [_buildLinkedComputerRow(context, active ?? computers.first)];
        }
        // Fall back to string fields on Dive entity
        return _buildDiveComputerStringRows(context);
      },
      loading: () => _buildDiveComputerStringRows(context),
      error: (_, _) => _buildDiveComputerStringRows(context),
    );
  }

  /// Fallback: build computer rows from the Dive entity's string fields.
  List<Widget> _buildDiveComputerStringRows(BuildContext context) {
    if (dive.diveComputerModel == null || dive.diveComputerModel!.isEmpty) {
      return [];
    }
    return [
      DiveDetailRow(
        label: context.l10n.diveLog_detail_label_diveComputer,
        value: dive.diveComputerModel!,
      ),
      if (dive.diveComputerSerial != null &&
          dive.diveComputerSerial!.isNotEmpty)
        DiveDetailRow(
          label: context.l10n.diveLog_detail_label_serialNumber,
          value: dive.diveComputerSerial!,
          copyable: true,
        ),
      if (dive.diveComputerFirmware != null &&
          dive.diveComputerFirmware!.isNotEmpty)
        DiveDetailRow(
          label: context.l10n.diveLog_detail_label_firmwareVersion,
          value: dive.diveComputerFirmware!,
        ),
    ];
  }

  /// Build a tappable row for a linked dive computer that navigates to
  /// the device detail page.
  Widget _buildLinkedComputerRow(BuildContext context, DiveComputer computer) {
    // A node of its own: in the Card it would merge into the card's.
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.diveLog_detail_semantics_viewDiveComputer(
        computer.displayName,
      ),
      child: InkWell(
        onTap: () => context.push(diveComputerLocation(computer)),
        child: DiveDetailLinkRow(
          label: context.l10n.diveLog_detail_label_diveComputer,
          title: computer.displayName,
          subtitle:
              computer.serialNumber != null && computer.serialNumber!.isNotEmpty
              ? context.l10n.diveLog_detail_serialNumber(computer.serialNumber!)
              : null,
        ),
      ),
    );
  }
}
