import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/safety_hub_summaries.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The pages beneath Settings > Safety, in the order the hub lists them.
enum SafetySubPage {
  review('review'),
  decompression('decompression'),
  equipmentCondition('equipment-condition');

  /// The page's path segment on phone and its `safetyPage` value on desktop.
  final String id;

  const SafetySubPage(this.id);

  /// The route a phone pushes to open this page.
  String get phoneRoute => '/settings/safety/$id';

  /// The page named [id], or null when [id] names no page.
  static SafetySubPage? fromId(String? id) {
    for (final page in values) {
      if (page.id == id) return page;
    }
    return null;
  }
}

/// Settings > Safety: one row per safety sub-page, each subtitled with what
/// that page is currently set to.
///
/// [onOpenPage] decides how a row opens its page. Null means push the page's
/// phone route; the desktop settings pane passes a callback that swaps the
/// pane content instead.
class SafetyHubPage extends ConsumerWidget {
  final void Function(SafetySubPage page)? onOpenPage;

  const SafetyHubPage({super.key, this.onOpenPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);

    void open(SafetySubPage page) {
      final callback = onOpenPage;
      if (callback != null) {
        callback(page);
      } else {
        context.push(page.phoneRoute);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_section_safety_title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SafetyHubRow(
            page: SafetySubPage.review,
            icon: Icons.fact_check_outlined,
            accentId: 'safety',
            title: l10n.safetySettings_title,
            subtitle: safetyReviewSummary(l10n, settings),
            onTap: open,
          ),
          const Divider(height: 1),
          _SafetyHubRow(
            page: SafetySubPage.decompression,
            icon: Icons.timeline,
            accentId: 'decompression',
            title: l10n.settings_section_decompression_title,
            subtitle: decompressionSummary(l10n, settings),
            onTap: open,
          ),
          const Divider(height: 1),
          _SafetyHubRow(
            page: SafetySubPage.equipmentCondition,
            icon: Icons.build_circle_outlined,
            accentId: 'safety',
            title: l10n.settings_section_equipmentCondition_title,
            subtitle: equipmentConditionSummary(l10n, settings),
            onTap: open,
          ),
        ],
      ),
    );
  }
}

/// A hub row, styled like the rows of the settings root list.
class _SafetyHubRow extends StatelessWidget {
  final SafetySubPage page;
  final IconData icon;
  final String accentId;
  final String title;
  final String subtitle;
  final void Function(SafetySubPage page) onTap;

  const _SafetyHubRow({
    required this.page,
    required this.icon,
    required this.accentId,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = settingsSectionColor(context, accentId);

    return ListTile(
      key: Key('safety-hub-${page.id}'),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => onTap(page),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
