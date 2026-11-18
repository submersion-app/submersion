import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_enum_chips_row.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_rules.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';

/// The Altitude card's editor: the altitude in the diver's unit and, for a
/// site with a position and no altitude, the elevation found for it,
/// offered beside the row and a change only once tapped (issue #4527,
/// phase 2).
class SiteAltitudeCardEditor extends ConsumerStatefulWidget {
  const SiteAltitudeCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  ConsumerState<SiteAltitudeCardEditor> createState() =>
      _SiteAltitudeCardEditorState();
}

class _SiteAltitudeCardEditorState
    extends ConsumerState<SiteAltitudeCardEditor> {
  double? _found;

  @override
  void initState() {
    super.initState();
    _askFound();
  }

  /// Handed another sitting, the suggestion is that sitting's own.
  @override
  void didUpdateWidget(SiteAltitudeCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _found = null;
    _askFound();
  }

  void _askFound() {
    final session = widget.session;
    final container = ProviderScope.containerOf(context, listen: false);
    foundAltitude(
      session,
      (point) => fetchSiteElevation(container, point),
    ).then((metres) {
      if (!mounted || metres == null || widget.session != session) return;
      setState(() => _found = metres);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final found = _found;
        // Found for the stored position: not once the site has moved.
        final offer =
            found != null &&
            session.valueOf(siteAltitudeField) == null &&
            session.valueOf(siteLocationField) == session.stored.location;
        return RecordNumberRow<DiveSite>(
          session: session,
          field: siteAltitudeField,
          label: l10n.diveSites_edit_section_altitude,
          suffixText: units.altitudeSymbol,
          placeholder: l10n.diveSites_edit_altitude_hint,
          // As the form: no altitude below sea level.
          allowNegative: false,
          toDisplay: units.convertAltitude,
          fromDisplay: units.altitudeToMeters,
          suggestion: offer
              ? ProfileSuggestion(
                  value: units.convertAltitude(found).toStringAsFixed(0),
                  onUse: () => session.set(siteAltitudeField, found),
                  tooltip: l10n.diveSites_edit_altitude_foundTooltip,
                )
              : null,
        );
      },
    );
  }
}

/// Whether the sitting's depth range can be saved: the minimum no deeper
/// than the maximum, or either one left out. A range stored out of order
/// and unchanged is not the diver's to fix before saving another card.
bool siteDepthRangeIsValid(EditSession<DiveSite> session) {
  final min = session.valueOf(siteMinDepthField);
  final max = session.valueOf(siteMaxDepthField);
  if (min == null || max == null || min <= max) return true;
  final stored = session.stored;
  return min == stored.minDepth && max == stored.maxDepth;
}

/// The Depth card's editor: the shallowest and deepest points, in the
/// diver's depth unit.
class SiteDepthCardEditor extends ConsumerWidget {
  const SiteDepthCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    Widget row(EditField<DiveSite, double?> field, String label) =>
        RecordNumberRow<DiveSite>(
          session: session,
          field: field,
          label: label,
          fractionDigits: 1,
          trimZeros: true,
          allowNegative: false,
          toDisplay: units.convertDepth,
          fromDisplay: units.depthToMeters,
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          siteMinDepthField,
          l10n.diveSites_edit_depth_minLabel(units.depthSymbol),
        ),
        row(
          siteMaxDepthField,
          l10n.diveSites_edit_depth_maxLabel(units.depthSymbol),
        ),
        // Why Save is refused, while the range is out of order.
        ListenableBuilder(
          listenable: session,
          builder: (context, _) => siteDepthRangeIsValid(session)
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text(
                    l10n.diveSites_edit_depth_rangeInvalid,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// The Difficulty card's editor: one level, cleared by tapping it again.
class SiteDifficultyCardEditor extends StatelessWidget {
  const SiteDifficultyCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SiteEnumChipsRow<SiteDifficulty>(
      session: session,
      field: siteDifficultyField,
      label: l10n.diveSites_edit_section_difficultyLevel,
      values: SiteDifficulty.values,
      name: (level) => level.localizedName(l10n),
    );
  }
}

/// The Rating card's editor: the diver's stars, and clear.
class SiteRatingCardEditor extends StatelessWidget {
  const SiteRatingCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => FormRow.rating(
        label: l10n.diveSites_edit_section_rating,
        value: (session.valueOf(siteRatingField) ?? 0).round(),
        onChanged: (stars) => session.set(siteRatingField, stars.toDouble()),
        onClear: () => session.set(siteRatingField, null),
        clearTooltip: l10n.common_action_clearRating,
      ),
    );
  }
}
