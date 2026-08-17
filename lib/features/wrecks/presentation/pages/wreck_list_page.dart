import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/wrecks/presentation/pages/wreck_detail_page.dart';
import 'package:submersion/features/wrecks/presentation/widgets/wreck_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// The wreck catalogue: the same master-detail shape the sites list uses,
/// so selection, deep links, and the wide-screen split behave identically.
class WreckListPage extends ConsumerWidget {
  const WreckListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return MasterDetailScaffold(
      sectionId: 'wrecks',
      // Note the parameter order: the scaffold passes the callback first,
      // then the current selection.
      masterBuilder: (context, onItemSelected, selectedId) => WreckListContent(
        selectedId: selectedId,
        onWreckSelected: onItemSelected,
        onAddWreck: () => context.push('/wrecks/new'),
      ),
      detailBuilder: (context, id) =>
          WreckDetailPage(wreckId: id, embedded: true),
      summaryBuilder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sailing_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                l10n.wrecks_empty_title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(l10n.wrecks_empty_body, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      // No inline edit/create builders: both navigate to the full page,
      // which keeps one edit surface rather than two.
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('wreckFab'),
        onPressed: () => context.push('/wrecks/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.wrecks_add),
      ),
    );
  }
}
