import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The page's answer: the strongest standouts as plain sentences.
class FocusStandoutsCard extends ConsumerWidget {
  const FocusStandoutsCard({super.key, required this.report});

  static const int maxFindings = 5;

  final FocusFactorReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final typesById = watchDiveTypesById(ref);
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );

    // Sorted once: the getter filters and sorts on every call.
    final standouts = report.standouts;
    final Widget body;
    if (report.tooFewDives) {
      body = Text(l10n.insights_focus_standouts_tooFew);
    } else if (standouts.isEmpty) {
      body = Text(l10n.insights_focus_standouts_none);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in standouts.take(maxFindings))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _sentence(f, l10n, units, percent, typesById),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          if (standouts.length > maxFindings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.insights_focus_standouts_more(
                  standouts.length - maxFindings,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      );
    }
    return StatSectionCard(
      title: l10n.insights_focus_standouts_title,
      child: body,
    );
  }

  String _sentence(
    FocusFactor f,
    AppLocalizations l10n,
    UnitFormatter units,
    NumberFormat percent,
    Map<String, DiveTypeEntity> typesById,
  ) {
    switch (f) {
      case NumericFactor(
        :final groupMean,
        :final baselineMean,
        :final difference,
      ):
        return l10n.insights_focus_standouts_numeric(
          focusFactorName(f.id, l10n),
          focusNumericMagnitude(f.id, difference!, units, l10n),
          focusDirectionWord(f.id, difference, l10n),
          focusNumericValue(f.id, groupMean!, units, l10n),
          focusNumericValue(f.id, baselineMean!, units, l10n),
        );
      case CategoricalFactor(:final top):
        final share = top.firstWhere((s) => s.standsOut);
        final value = focusCategoryLabel(
          f.id,
          share,
          l10n,
          units,
          typesById: typesById,
        );
        final baseline = percent.format(share.baselineShare);
        return share.groupCount >= f.groupSize
            ? l10n.insights_focus_standouts_categoryAll(
                share.groupCount,
                value,
                baseline,
              )
            : l10n.insights_focus_standouts_categorySome(
                share.groupCount,
                f.groupSize,
                value,
                baseline,
              );
    }
  }
}
