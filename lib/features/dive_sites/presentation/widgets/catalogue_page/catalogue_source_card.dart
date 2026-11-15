import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_page_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a built-in site's record came from: the source's name, the
/// credit it asks for, its licence, and links to the source and to the
/// site's own website.
///
/// A charted wreck or reef adds that it is a charted position and not a
/// dive guide. Every link opens only as a web address
/// (`catalogueWebsiteUri`): the values come from sources anyone can edit.
class CatalogueSourceCard extends ConsumerWidget {
  const CatalogueSourceCard({super.key, required this.site});

  final CatalogueSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final source = ref.watch(catalogueSourceProvider(site.source)).value;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final licenceUri = catalogueWebsiteUri(source?.licenceUrl);
    final sourceUri = catalogueSourceLinkUri(site, source);
    final websiteUri = catalogueWebsiteUri(site.website);
    final isRegister = site.kind == CatalogueKind.register;
    if (source == null &&
        sourceUri == null &&
        websiteUri == null &&
        !isRegister) {
      return const SizedBox.shrink();
    }

    return CataloguePageCard(
      icon: Icons.source_outlined,
      title: l10n.diveSites_builtInPage_source,
      children: [
        if (source != null) ...[
          Text(source.name, style: theme.textTheme.bodyMedium),
          // A source whose credit is its own name is not said twice.
          if (source.credit != source.name)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.diveSites_builtInPage_credit(source.credit),
                style: muted,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _LicenceLine(
              text: l10n.diveSites_builtInPage_licence(source.licence),
              uri: licenceUri,
              style: muted,
            ),
          ),
        ],
        if (sourceUri != null || websiteUri != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 16,
              children: [
                if (sourceUri != null)
                  _Link(
                    key: const ValueKey('catalogueSourceLink'),
                    label: l10n.diveSites_builtInPage_source,
                    uri: sourceUri,
                  ),
                if (websiteUri != null)
                  _Link(
                    key: const ValueKey('catalogueWebsiteLink'),
                    label: l10n.diveCenters_label_website,
                    uri: websiteUri,
                  ),
              ],
            ),
          ),
        if (isRegister)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.diveSites_builtInPage_notAGuide, style: muted),
          ),
      ],
    );
  }
}

/// The licence by name, opening the licence's own page when it has one.
class _LicenceLine extends StatelessWidget {
  const _LicenceLine({required this.text, required this.uri, this.style});

  final String text;
  final Uri? uri;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final target = uri;
    if (target == null) return Text(text, style: style);
    return InkWell(
      key: const ValueKey('catalogueLicenceLink'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => launchUrl(target, mode: LaunchMode.externalApplication),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, style: style)),
          const SizedBox(width: 4),
          Icon(Icons.open_in_new, size: 14, color: style?.color),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({super.key, required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(padding: EdgeInsets.zero),
    onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
    icon: const Icon(Icons.open_in_new, size: 16),
    label: Text(label),
  );
}
