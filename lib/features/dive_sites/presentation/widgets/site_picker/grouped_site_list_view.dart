import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The location a site row shows under its name inside a country group: the
/// parts the country and region headers above it do not already state.
String? siteGroupedSubtitle(DiveSite site) {
  final water = site.bodyOfWater?.trim() ?? '';
  final parts = [site.locality, water].where((part) => part.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// A country group's header text, naming the no-country group.
String countryGroupLabel(
  AppLocalizations l10n,
  SiteCountryGroup<Object?> group,
) => group.isNoCountry ? l10n.diveSites_group_noCountry : group.label;

/// Tappable header that opens or closes one country group.
///
/// A plain row rather than a ListTile: the site count is text, and text in
/// ListTile.trailing squeezes the title (#2717).
class SiteCountryHeader extends StatelessWidget {
  const SiteCountryHeader({
    super.key,
    required this.label,
    required this.siteCount,
    required this.isExpanded,
    required this.onTap,
  });

  final String label;
  final int siteCount;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      expanded: isExpanded,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.diveSites_group_siteCount(siteCount),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small section label: a region inside a country group, or the picker's
/// Nearby section.
class SiteSectionLabel extends StatelessWidget {
  const SiteSectionLabel(this.text, {super.key, this.indent = 16});

  final String text;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(indent, 8, 16, 4),
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
