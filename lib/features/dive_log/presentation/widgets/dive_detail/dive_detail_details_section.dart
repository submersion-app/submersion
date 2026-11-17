import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/info/dive_details_info.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_mode_label.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_course_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_details_derived_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_link.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';

/// The Details card, the same one in the normal section flow and beside
/// Conditions.
class DiveDetailsSection extends ConsumerWidget {
  const DiveDetailsSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final title = context.l10n.diveLog_detail_section_details;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordCardHeader(
                title: title,
                trailing: HeaderInfoButton(
                  title: title,
                  content: (context) {
                    final display = ref.read(gasConsumptionDisplayProvider);
                    return diveDetailsInfo(
                      context.l10n,
                      infoUnits(context),
                      showsSac: display.showsSac,
                      showsRmv: display.showsRmv,
                      // The row shows only with both factors.
                      hasGradientFactors:
                          dive.gradientFactorLow != null &&
                          dive.gradientFactorHigh != null,
                    );
                  },
                ),
              ),
              const Divider(),
              DiveDetailRow(
                label: context.l10n.diveLog_detail_label_diveType,
                value: diveTypeLabels(
                  context.l10n,
                  dive.diveTypeIds,
                  typesById: {
                    for (final t
                        in ref.watch(diveTypesProvider).value ??
                            const <DiveTypeEntity>[])
                      t.id: t,
                  },
                ),
              ),
              DiveDetailRow(
                label: context.l10n.diveLog_diveMode_title,
                value: diveModeLabel(context.l10n, dive.diveMode),
              ),
              if (dive.trip != null) _buildTripRow(context),
              if (dive.trip != null)
                PartOfTripLink(
                  tripId: dive.trip!.id,
                  padding: const EdgeInsets.only(bottom: 8),
                ),
              if (dive.diveCenter != null) _buildDiveCenterRow(context),
              // Free text from the editor or a MacDive/UDDF import (#3229).
              for (final (label, value) in [
                (
                  context.l10n.diveLog_detail_label_diveOperator,
                  dive.diveOperator,
                ),
                (context.l10n.diveLog_detail_label_boatName, dive.boatName),
                (
                  context.l10n.diveLog_detail_label_boatCaptain,
                  dive.boatCaptain,
                ),
              ])
                if (trimmedOrNull(value) case final text?)
                  DiveDetailRow(label: label, value: text),
              // From the dive as the page holds it, which during a sitting
              // is ahead of what is stored.
              if (dive.courseIds.isNotEmpty)
                DiveCourseRows(diveId: dive.id, courseIds: dive.courseIds),
              if (formatDiveVisibility(
                    meters: dive.visibilityMeters,
                    range: dive.visibilityRange,
                    legacy: dive.visibility,
                    scale: ref.watch(
                      settingsProvider.select((s) => s.visibilityScale),
                    ),
                    l10n: context.l10n,
                    units: units,
                  )
                  case final visibility?)
                DiveDetailRow(
                  label: context.l10n.diveLog_detail_label_visibility,
                  value: visibility,
                ),
              if (dive.avgDepth != null)
                DiveDetailRow(
                  label: context.l10n.diveLog_detail_label_avgDepth,
                  value: units.formatDepth(dive.avgDepth),
                ),
              // Effective, so a dive that never had a water type of its own
              // still shows the one its site carries (issue #1427).
              if (dive.effectiveWaterType != null)
                DiveDetailRow(
                  label: context.l10n.diveLog_detail_label_waterType,
                  value: dive.effectiveWaterType!.localizedName(context.l10n),
                ),
              DiveDetailsDerivedRows(dive: dive),
              // An exclusion is set on this card, and would otherwise be
              // nowhere on the page.
              if (diveStatisticsExclusion(context.l10n, dive) case final text?)
                DiveDetailRow(
                  label: context.l10n.diveLog_edit_group_statistics,
                  value: text,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripRow(BuildContext context) {
    final trip = dive.trip!;
    // A node of its own: in the Card it would merge into the card's.
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.diveLog_detail_semantics_viewTrip(trip.name),
      child: InkWell(
        onTap: () => context.push('/trips/${trip.id}'),
        child: DiveDetailLinkRow(
          label: context.l10n.diveLog_edit_section_trip,
          title: trip.name,
          subtitle: trip.subtitle,
        ),
      ),
    );
  }

  Widget _buildDiveCenterRow(BuildContext context) {
    final logo = dive.diveCenter!.logo;
    // A node of its own: in the Card it would merge into the card's.
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.diveLog_detail_semantics_viewDiveCenter(
        dive.diveCenter!.name,
      ),
      child: InkWell(
        onTap: () => context.push('/dive-centers/${dive.diveCenter!.id}'),
        child: DiveDetailLinkRow(
          label: context.l10n.diveLog_edit_section_diveCenter,
          title: dive.diveCenter!.name,
          // The center's logo when it has one (#4460); the row keeps its
          // plain look otherwise, like the trip row above it.
          leading: logo == null
              ? null
              : DiveCenterAvatar(
                  logo: logo,
                  radius: 10,
                  shape: DiveCenterAvatarShape.roundedSquare,
                  cornerRadius: 4,
                ),
        ),
      ),
    );
  }
}
