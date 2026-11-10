import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/collapsible_group_header.dart';

/// The location a site row shows under its name inside a country group: the
/// parts the country and region headers above it do not already state.
String? siteGroupedSubtitle(DiveSite site) {
  final water = site.bodyOfWater?.trim() ?? '';
  final parts = [site.locality, water].where((part) => part.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// An outer group's header text, naming the ungrouped group with
/// [noGroupLabel] (e.g. "No country", "No body of water").
String siteOuterGroupLabel(
  String noGroupLabel,
  SiteOuterGroup<Object?> group,
) => group.isUngroupedKey ? noGroupLabel : group.label;

/// A subgroup's header text, naming its ungrouped subgroup with
/// [noGroupLabel] (e.g. a country's sites with no body of water, #3270).
String siteSubGroupLabel(String noGroupLabel, SiteSubGroup<Object?> subgroup) =>
    subgroup.isUngroupedKey ? noGroupLabel : subgroup.label;

/// Tappable header that opens or closes one outer group, drawn by the
/// shared [CollapsibleGroupHeader].
///
/// A plain row rather than a ListTile: the site count is text, and text in
/// ListTile.trailing squeezes the title (#2717).
class SiteGroupHeader extends StatelessWidget {
  const SiteGroupHeader({
    super.key,
    required this.label,
    required this.siteCount,
    required this.isExpanded,
    required this.onTap,
    this.indent = 16,
  });

  final String label;
  final int siteCount;
  final bool isExpanded;
  final VoidCallback onTap;

  /// Left padding, deeper for a subgroup header than its outer group's.
  final double indent;

  @override
  Widget build(BuildContext context) => CollapsibleGroupHeader(
    label: label,
    countLabel: context.l10n.diveSites_group_siteCount(siteCount),
    isExpanded: isExpanded,
    onTap: onTap,
    indent: indent,
  );
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
