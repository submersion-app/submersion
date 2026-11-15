import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_gap_display.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/not_verified_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver did with a comparison.
sealed class CatalogueComparisonResult {
  const CatalogueComparisonResult();
}

/// Closed without acting: [fields] are the ticks as they were left, for
/// the list row to apply later.
class ComparisonKept extends CatalogueComparisonResult {
  const ComparisonKept(this.fields);
  final Set<CatalogueGapField> fields;
}

/// Apply the pair now, filling [fields]. Empty links the site and fills
/// nothing.
class ComparisonApply extends CatalogueComparisonResult {
  const ComparisonApply(this.fields);
  final Set<CatalogueGapField> fields;
}

/// The record is a different place from the site.
class ComparisonNotSame extends CatalogueComparisonResult {
  const ComparisonNotSame();
}

/// The site is the record's, and the diver wants none of what it offers.
class ComparisonNoThanks extends CatalogueComparisonResult {
  const ComparisonNoThanks();
}

/// Shows one of the diver's sites beside the catalogue record paired with
/// it: a tick per field the record would fill, and what stays the diver's.
///
/// The sheet writes nothing. It answers with what the diver chose, and the
/// caller acts on it; dismissing it answers [ComparisonKept] with the ticks
/// as they stood. [initialFields] are the fields ticked to start, every
/// offered one when null.
Future<CatalogueComparisonResult> showCatalogueGapComparison(
  BuildContext context, {
  required CataloguePair pair,
  Set<CatalogueGapField>? initialFields,
}) async {
  var fields = initialFields?.intersection(pair.fields) ?? pair.fields;
  final result = await showModalBottomSheet<CatalogueComparisonResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _Comparison(
      pair: pair,
      initialFields: fields,
      onFieldsChanged: (next) => fields = next,
    ),
  );
  return result ?? ComparisonKept(fields);
}

class _Comparison extends ConsumerStatefulWidget {
  const _Comparison({
    required this.pair,
    required this.initialFields,
    required this.onFieldsChanged,
  });

  final CataloguePair pair;
  final Set<CatalogueGapField> initialFields;
  final ValueChanged<Set<CatalogueGapField>> onFieldsChanged;

  @override
  ConsumerState<_Comparison> createState() => _ComparisonState();
}

class _ComparisonState extends ConsumerState<_Comparison> {
  late Set<CatalogueGapField> _fields = widget.initialFields;

  /// A new set each time: the one handed out before is never changed.
  void _toggle(CatalogueGapField field) {
    setState(() {
      _fields = _fields.contains(field)
          ? _fields.difference({field})
          : {..._fields, field};
    });
    widget.onFieldsChanged(_fields);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final units = ref.watch(unitFormatterProvider);
    final pair = widget.pair;
    final site = pair.site;
    final record = pair.record;
    final credit = ref.watch(catalogueSourceProvider(record.source)).value;
    final place = catalogueLocationLine(record);
    final siteAt = site.location;
    final recordAt = record.location;
    final distance = pair.distanceMeters;

    /// Two captioned values side by side: the diver's and the record's.
    Widget sideBySide(String yours, String theirs) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.diveSites_gapCompare_yours, style: muted),
              Text(yours),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.diveSites_gapCompare_record, style: muted),
              Text(theirs),
            ],
          ),
        ),
      ],
    );

    /// A value of the diver's that nothing here can change.
    Widget kept(String label, String yours, String theirs, String note) =>
        ListTile(
          // Lines up with the ticked rows above it.
          leading: const SizedBox(width: 40),
          title: Text(label),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              sideBySide(yours, theirs),
              const SizedBox(height: 2),
              Text(note, style: muted),
            ],
          ),
        );

    final primary = _fields.isNotEmpty
        ? l10n.diveSites_gapCompare_fill(_fields.length)
        : pair.addsLink
        ? l10n.diveSites_gapCompare_linkOnly
        : l10n.diveSites_gapCompare_fill(0);
    // A linked site with nothing ticked has nothing to gain.
    final canApply = _fields.isNotEmpty || pair.addsLink;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sideBySide(site.name, record.name),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(place, style: muted),
                ],
                if (credit != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.diveSites_catalogue_credit(credit.credit),
                    style: muted,
                  ),
                ],
                if (record.isResearched) ...[
                  const SizedBox(height: 8),
                  const NotVerifiedLabel(),
                  const SizedBox(height: 4),
                  Text(
                    notVerifiedExplanation(context),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          for (final field in pair.fields)
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: _fields.contains(field),
              onChanged: (_) => _toggle(field),
              title: Text(catalogueGapFieldLabel(field, l10n)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: sideBySide(
                  l10n.diveSites_gapCompare_empty,
                  catalogueGapFieldValue(field, record, units, l10n),
                ),
              ),
            ),
          kept(
            l10n.diveSites_gapField_name,
            site.name,
            record.name,
            l10n.diveSites_gapCompare_staysYours,
          ),
          if (siteAt != null && recordAt != null)
            kept(
              l10n.diveSites_detail_location_gpsCoordinates,
              catalogueCoordinatesText(siteAt),
              catalogueCoordinatesText(recordAt),
              distance == null
                  ? l10n.diveSites_gapCompare_staysYours
                  : '${l10n.diveSites_gapCompare_staysYours} · '
                        '${l10n.diveSites_gapCompare_apart(units.formatDistance(distance))}',
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              overflowSpacing: 8,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    pair.addsLink
                        ? const ComparisonNotSame()
                        : const ComparisonNoThanks(),
                  ),
                  child: Text(
                    pair.addsLink
                        ? l10n.diveSites_gapCompare_notSame
                        : l10n.diveSites_gapCompare_noThanks,
                  ),
                ),
                FilledButton(
                  onPressed: canApply
                      ? () =>
                            Navigator.of(context).pop(ComparisonApply(_fields))
                      : null,
                  child: Text(primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
