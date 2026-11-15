import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_gap_display.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/catalogue_gap_review_notifier.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/not_verified_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The diver's existing sites that a built-in catalogue record matches,
/// with what each record would add, for the diver to review and apply.
///
/// Rows the app is sure of arrive ticked; the rest are for the diver to
/// check. Nothing is written until Apply, and a row left un-ticked simply
/// stays for next time.
class CatalogueGapReviewPage extends ConsumerWidget {
  const CatalogueGapReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(catalogueGapReviewProvider);
    final notifier = ref.read(catalogueGapReviewProvider.notifier);
    final units = ref.watch(unitFormatterProvider);

    void say(String message) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    void report(CatalogueApplyResult result) =>
        say(catalogueApplyResultMessage(result, l10n));

    Future<void> applyTicked() async {
      try {
        final result = await notifier.applyTicked();
        if (result == null || !context.mounted) return;
        report(result);
      } catch (_) {
        // The notifier has logged it; the rows are still there to retry.
        if (context.mounted) say(l10n.diveSites_gapReview_error);
      }
    }

    Future<void> openComparison(CataloguePair pair) async {
      final result = await showCatalogueGapComparison(
        context,
        pair: pair,
        initialFields: ref.read(catalogueGapReviewProvider).fieldsFor(pair),
      );
      try {
        switch (result) {
          case ComparisonKept(:final fields):
            notifier.setFields(pair, fields);
          case ComparisonApply(:final fields):
            final applied = await notifier.applyOne(pair, fields);
            if (applied != null && context.mounted) report(applied);
          case ComparisonNotSame():
            await notifier.notSame(pair);
          case ComparisonNoThanks():
            await notifier.noThanks(pair);
        }
      } catch (_) {
        if (context.mounted) say(l10n.diveSites_gapReview_error);
      }
    }

    final same = [
      for (final pair in state.pairs)
        if (pair.preTicked) pair,
    ];
    final check = [
      for (final pair in state.pairs)
        if (!pair.preTicked) pair,
    ];
    // The list top to bottom: a section's title, then its pairs. Only the
    // rows on screen are built from it.
    final entries = <Object>[
      if (same.isNotEmpty) ...[
        l10n.diveSites_gapReview_sectionSame(same.length),
        ...same,
      ],
      if (check.isNotEmpty) ...[
        l10n.diveSites_gapReview_sectionCheck(check.length),
        ...check,
      ],
    ];

    Widget entry(BuildContext context, int index) => switch (entries[index]) {
      final CataloguePair pair => _PairRow(
        pair: pair,
        fields: state.fieldsFor(pair),
        ticked: state.ticked.contains(pair.site.id),
        units: units,
        enabled: !state.isWriting,
        onToggle: () => notifier.toggle(pair.site.id),
        onOpen: () => openComparison(pair),
      ),
      // Whatever is not a pair is a section's title.
      final title => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '$title',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diveSites_gapReview_title)),
      // Nothing to offer and "not found yet" read the same: the page never
      // waits on the catalogue, and the rows appear when they are ready.
      body: state.pairs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.diveSites_gapReview_empty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: entries.length,
              itemBuilder: entry,
            ),
      bottomNavigationBar: state.pairs.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: state.tickedCount == 0 || state.isWriting
                      ? null
                      : applyTicked,
                  child: Text(
                    l10n.diveSites_gapReview_apply(state.tickedCount),
                  ),
                ),
              ),
            ),
    );
  }
}

/// One pair: a tick, the site's name, how the record was found when that
/// needs saying, and what applying it would add.
class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.pair,
    required this.fields,
    required this.ticked,
    required this.units,
    required this.enabled,
    required this.onToggle,
    required this.onOpen,
  });

  final CataloguePair pair;

  /// The fields the row's tick would fill: the offered ones less those the
  /// diver un-ticked in the comparison.
  final Set<CatalogueGapField> fields;
  final bool ticked;
  final UnitFormatter units;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  /// How the record was found, for the pairs the diver should check: how
  /// far away and under what name, or that the site has no position.
  String? _found(AppLocalizations l10n) {
    switch (pair.kind) {
      case CataloguePairKind.linked || CataloguePairKind.sure:
        return null;
      case CataloguePairKind.nearby:
        return l10n.diveSites_gapReview_nearby(
          units.formatDistance(pair.distanceMeters ?? 0),
          pair.record.name,
        );
      case CataloguePairKind.named:
        final place = catalogueLocationLine(pair.record);
        return place.isEmpty
            ? l10n.diveSites_gapReview_namedNoPlace(pair.record.name)
            : l10n.diveSites_gapReview_named(pair.record.name, place);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final found = _found(l10n);
    return ListTile(
      leading: Checkbox(
        value: ticked,
        // The tick is its own stop for a screen reader, apart from the
        // row: unnamed, every one of them reads as just "tick box".
        semanticLabel: pair.site.name,
        onChanged: enabled ? (_) => onToggle() : null,
      ),
      title: Text(pair.site.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (found != null) Text(found),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(catalogueGapAddsLine(pair, units, l10n, fields: fields)),
              if (pair.record.isResearched) const NotVerifiedLabel(),
            ],
          ),
        ],
      ),
      isThreeLine: found != null,
      trailing: IconButton(
        icon: const Icon(Icons.chevron_right),
        tooltip: l10n.diveSites_gapReview_compare,
        onPressed: enabled ? onOpen : null,
      ),
      onTap: enabled ? onOpen : null,
    );
  }
}
