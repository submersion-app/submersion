import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/wrecks/presentation/providers/wreck_providers.dart';
import 'package:submersion/features/wrecks/presentation/widgets/wreck_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Catalogue wrecks linked to this site, shown on site detail. Renders
/// nothing when the site has none, so an empty section never takes up
/// space on a page that is already long.
class SiteWrecksSection extends ConsumerWidget {
  final String siteId;

  const SiteWrecksSection({super.key, required this.siteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final wrecks = ref.watch(wrecksForSiteProvider(siteId)).valueOrNull ?? [];
    if (wrecks.isEmpty) return const SizedBox.shrink();

    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sailing, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.wrecks_sectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final w in wrecks)
              Builder(
                builder: (context) {
                  // Null, not an empty Text: an unknown type and depth
                  // would otherwise leave a blank subtitle line.
                  final subtitle = [
                    wreckVesselTypeLabel(l10n, w.vesselTypeName),
                    wreckMeasure(
                      w.depthToDeckMeters,
                      unitInMeters,
                      depthUnit.symbol,
                    ),
                  ].where((s) => s.isNotEmpty).join(' • ');
                  return ListTile(
                    key: ValueKey('siteWreckRow-${w.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sailing_outlined),
                    title: Text(w.name),
                    subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/wrecks/${w.id}'),
                  );
                },
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('siteWreckLinkButton'),
                icon: const Icon(Icons.add),
                label: Text(l10n.wrecks_link),
                onPressed: () => context.push('/wrecks/new'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
