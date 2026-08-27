import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

/// Info card shown when a built-in (bundled) site marker is tapped.
/// Offers a primary "Add to my sites" action that imports the site.
class BuiltInSiteInfoCard extends StatelessWidget {
  final ExternalDiveSite site;
  final Future<void> Function() onAdd;

  const BuiltInSiteInfoCard({
    super.key,
    required this.site,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      site.region,
      site.country,
    ].where((e) => e != null && e.isNotEmpty).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(site.name, style: theme.textTheme.titleMedium),
            if (location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(location, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_location_alt, size: 18),
                label: Text(context.l10n.diveSites_map_builtInSites_add),
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
