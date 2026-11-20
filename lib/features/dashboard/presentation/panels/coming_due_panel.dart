import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a coming-due item opens.
String comingDueRoute(ComingDueItem item) => switch (item.kind) {
  ComingDueKind.gear => '/equipment/${item.id}',
  ComingDueKind.insurance => '/documents?type=insurance',
  ComingDueKind.certification => '/certifications/${item.id}',
  ComingDueKind.document => '/documents/${item.id}',
};

IconData _icon(ComingDueKind kind) => switch (kind) {
  ComingDueKind.gear => Icons.build_outlined,
  ComingDueKind.insurance => Icons.health_and_safety_outlined,
  ComingDueKind.certification => Icons.card_membership_outlined,
  ComingDueKind.document => Icons.folder_copy_outlined,
};

/// The next things with a date: gear services, the insurance policy,
/// certifications and documents, soonest first. Each row opens its item.
class ComingDuePanel extends ConsumerWidget {
  const ComingDuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final items = ref.watch(homeComingDueProvider);
    final first = items.value?.firstOrNull;
    final now = DateTime.now();
    return HomePanel(
      title: l10n.dashboard_panel_comingDue,
      semanticsValue: first == null
          ? l10n.dashboard_panel_nothingDue
          : '${first.name} ${units.formatDate(first.due)}',
      onTap: first == null ? null : () => context.push(comingDueRoute(first)),
      fit: HomePanelFit.clip,
      child: HomePanelAsync<List<ComingDueItem>>(
        value: items,
        isEmpty: (i) => i.isEmpty,
        emptyText: l10n.dashboard_panel_nothingDue,
        builder: (list) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in list)
              InkWell(
                onTap: () => context.push(comingDueRoute(item)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        _icon(item.kind),
                        size: 14,
                        color: item.due.isBefore(now)
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        units.formatDate(item.due),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
