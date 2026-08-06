import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Attribution for the reef data sources.
///
/// Required: WRI Reefs at Risk is CC BY 3.0 and ProtectedSeas Navigator is
/// CC BY 4.0, both of which oblige attribution. GBIF records are filtered to
/// CC0 and CC BY. NOAA data is public domain but requests credit.
class ReefAttributionSheet extends StatelessWidget {
  const ReefAttributionSheet({super.key});

  /// Source names are proper nouns and stay untranslated; only the
  /// descriptions are localized.
  List<_Source> _sources(BuildContext context) => [
    _Source(
      name: 'WRI Reefs at Risk Revisited',
      detail: context.l10n.reef_attribution_wri,
      url: 'https://www.wri.org/research/reefs-risk-revisited',
    ),
    _Source(
      name: 'NOAA Coral Reef Watch',
      detail: context.l10n.reef_attribution_noaa,
      url: 'https://coralreefwatch.noaa.gov',
    ),
    _Source(
      name: 'GBIF',
      detail: context.l10n.reef_attribution_gbif,
      url: 'https://www.gbif.org',
    ),
    _Source(
      name: 'ProtectedSeas Navigator',
      detail: context.l10n.reef_attribution_protectedSeas,
      url: 'https://navigatormap.org',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.reef_attribution_title,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final source in _sources(context))
              ListTile(
                title: Text(source.name),
                subtitle: Text(source.detail),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(
                  Uri.parse(source.url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Source {
  final String name;
  final String detail;
  final String url;
  const _Source({required this.name, required this.detail, required this.url});
}
