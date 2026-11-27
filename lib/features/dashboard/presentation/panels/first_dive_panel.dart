import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown under the key numbers while the log is empty: the two ways to get
/// a first dive in. The chart panels below have nothing to show until then.
class FirstDivePanel extends StatelessWidget {
  const FirstDivePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HomePanel(
      title: l10n.dashboard_key_dives,
      semanticsValue: l10n.dashboard_panel_firstDive,
      // Clip: at large text in a long language the buttons wrap onto a
      // second line and the panel cuts off what does not fit.
      fit: HomePanelFit.clip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.dashboard_panel_firstDive,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.dashboard_quickActions_logDive),
                onPressed: () => showAddDiveBottomSheet(
                  context: context,
                  onLogManually: () => context.push('/dives/new'),
                  onPlanDive: () => context.push(
                    '/dives/new',
                    extra: const DivePrefill(isPlanned: true),
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined),
                label: Text(l10n.dashboard_panel_import),
                onPressed: () => context.push('/transfer/import-wizard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
