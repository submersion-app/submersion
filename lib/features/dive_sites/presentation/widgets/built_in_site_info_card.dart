import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything the built-in catalogue knows about one site, with one action:
/// "Add to my sites" on the map, "Use this site" in the site picker.
///
/// Shows only what the record has: a site that is no more than a name and
/// a position is a name and the action.
class BuiltInSiteInfoCard extends ConsumerStatefulWidget {
  final CatalogueSite site;
  final String actionLabel;

  /// Runs when the action is tapped. While it runs the button is disabled,
  /// so a second tap cannot adopt the site twice.
  final Future<void> Function() onAction;

  const BuiltInSiteInfoCard({
    super.key,
    required this.site,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  ConsumerState<BuiltInSiteInfoCard> createState() =>
      _BuiltInSiteInfoCardState();
}

class _BuiltInSiteInfoCardState extends ConsumerState<BuiltInSiteInfoCard> {
  bool _running = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await widget.onAction();
    } catch (error, stackTrace) {
      // Callers handle their own failures and tell the diver. One that
      // slips through must not be lost as an unhandled async error, nor
      // leave the button disabled.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'dive sites',
          context: ErrorDescription('while running a built-in site action'),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final site = widget.site;
    final units = ref.watch(unitFormatterProvider);
    final source = ref.watch(catalogueSourceProvider(site.source)).value;

    final location = catalogueLocationLine(site);
    final depth = catalogueDepthRange(site, units);
    final facts = [
      ...catalogueTypeNames(site, l10n),
      ...catalogueEntryNames(site, l10n),
      ?depth,
    ];
    final website = catalogueWebsiteUri(site.website);

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
            if (facts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [for (final fact in facts) _Fact(fact)],
                ),
              ),
            if (site.hazards != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 16,
                      color: theme.colorScheme.error,
                      semanticLabel: l10n.diveSites_detail_section_hazards,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        site.hazards!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            if (site.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  site.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (source != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.diveSites_import_detail_source(source.credit),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (website != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => launchUrl(
                      website,
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(l10n.diveCenters_label_website),
                  ),
                // Takes the rest of the row, so a long translated label
                // ("Zu meinen Tauchplätzen hinzufügen") wraps inside the
                // button instead of pushing the row past the card's edge.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_location_alt, size: 18),
                      label: Text(widget.actionLabel),
                      onPressed: _running ? null : _run,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One short fact about the site: a type, an entry, a depth.
class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(text, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

/// Shows [site]'s details in a bottom sheet with one action. Tapping the
/// action closes the sheet, then runs [onAction].
Future<void> showCatalogueSiteDetails(
  BuildContext context, {
  required CatalogueSite site,
  required String actionLabel,
  required Future<void> Function() onAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: BuiltInSiteInfoCard(
        site: site,
        actionLabel: actionLabel,
        onAction: () async {
          Navigator.of(sheetContext).pop();
          await onAction();
        },
      ),
    ),
  );
}
