import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A feature page item's title with its feature's health mark beside it
/// when one of [reasons] is among the feature's findings (#4561), so the
/// colour on the Settings > Data row shows on the item that causes it.
///
/// With [subjectId], only a finding about that item counts (one library,
/// one extra backup account). With no matching finding the title reads as
/// it always did.
class HealthMarkedTitle extends ConsumerWidget {
  const HealthMarkedTitle({
    super.key,
    required this.title,
    required this.feature,
    required this.reasons,
    this.subjectId,
  });

  final Widget title;
  final DataFeature feature;
  final Set<HealthReason> reasons;
  final String? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only this item's finding: other health changes leave it alone.
    final finding = ref.watch(
      healthProviderOf(
        feature,
      ).select((h) => findingFor(h, reasons, subjectId: subjectId)),
    );
    if (finding == null) return title;
    final l10n = context.l10n;
    return Row(
      children: [
        Flexible(child: title),
        const SizedBox(width: 8),
        HealthSymbol(
          level: finding.level,
          size: 16,
          semanticLabel: [
            healthLevelLabel(l10n, finding.level),
            healthReasonText(l10n, finding, DateTime.now()),
          ].join(', '),
        ),
      ],
    );
  }
}
