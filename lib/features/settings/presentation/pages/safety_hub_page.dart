import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/settings/presentation/pages/decompression_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_condition_settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/safety_review_settings_page.dart';
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

/// The Safety section inside the desktop settings detail pane.
///
/// Nothing is pushed in the pane, so the URL carries which page shows:
/// `/settings?selected=safety` is the hub and adding
/// `&safetyPage=<id>` shows that sub-page in its place, with a back arrow
/// that drops the parameter again. Driving it from the URL keeps the left
/// list on Safety, and lets deep links and window restore reopen the page.
class SafetySettingsPane extends StatelessWidget {
  const SafetySettingsPane({super.key});

  /// The query parameter naming the open sub-page.
  static const queryParam = 'safetyPage';

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final hubLocation = '${uri.path}?selected=safety';
    final page = SafetySubPage.fromId(uri.queryParameters[queryParam]);
    void back() => context.goInPlace(hubLocation);

    return switch (page) {
      null => SafetyHubPage(
        key: const ValueKey('safety-hub'),
        onOpenPage: (page) =>
            context.goInPlace('$hubLocation&$queryParam=${page.id}'),
      ),
      SafetySubPage.review => SafetyReviewSettingsPage(
        key: const ValueKey('safety-review'),
        onBack: back,
      ),
      SafetySubPage.decompression => DecompressionSettingsPage(
        key: const ValueKey('safety-decompression'),
        onBack: back,
      ),
      SafetySubPage.equipmentCondition => EquipmentConditionSettingsPage(
        key: const ValueKey('safety-equipment-condition'),
        onBack: back,
      ),
    };
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
