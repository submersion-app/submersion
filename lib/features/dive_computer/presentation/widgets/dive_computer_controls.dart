import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_computer/presentation/utils/connection_presentation.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_actions_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_clock_sync_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_connections_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_info_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_merge_actions.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_stats_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every control the app has for one registered dive computer: favourite,
/// merge, device info, connections, statistics, download and re-parse, and
/// clock sync. Shown on the computer's Equipment page (issue #3676), which
/// carries its name, notes, service and delete.
class DiveComputerControls extends ConsumerWidget {
  const DiveComputerControls({super.key, required this.computerId});

  final String computerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computerAsync = ref.watch(diveComputerByIdProvider(computerId));
    return computerAsync.when(
      data: (computer) => computer == null
          ? const SizedBox.shrink()
          : _Controls(computer: computer),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.diveComputer_error_generic(error.toString())),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections =
        ref.watch(diveComputerConnectionsProvider(computer.id)).valueOrNull ??
        const <DiveComputerConnection>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(computer: computer),
        const SizedBox(height: 8),
        DiveComputerDuplicateBanner(computer: computer),
        DiveComputerInfoCard(
          computer: computer,
          icon: computerConnectionIcon(computer, connections),
        ),
        const SizedBox(height: 16),
        DiveComputerConnectionsCard(computer: computer),
        const SizedBox(height: 16),
        DiveComputerStatsCard(computer: computer),
        const SizedBox(height: 16),
        DiveComputerActionsCard(computer: computer),
        const SizedBox(height: 16),
        DiveComputerClockSyncCard(computer: computer),
      ],
    );
  }
}

/// The section title, with the favourite star and the merge action that
/// were on the computer page's app bar.
class _Header extends ConsumerWidget {
  const _Header({required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.diveComputer_title,
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (computer.isFavorite)
          IconButton(
            icon: Icon(Icons.star, color: theme.colorScheme.primary),
            onPressed: () {},
            tooltip: l10n.diveComputer_status_favorite,
          )
        else
          IconButton(
            icon: const Icon(Icons.star_outline),
            onPressed: () => ref
                .read(diveComputerNotifierProvider.notifier)
                .setFavorite(computer.id),
            tooltip: l10n.diveComputer_action_setFavorite,
          ),
        IconButton(
          key: const ValueKey('dive_computer_merge'),
          icon: const Icon(Icons.merge_type),
          tooltip: l10n.diveComputer_detail_mergeMenu,
          onPressed: () => logFailure(
            showDiveComputerMergePicker(context, ref, computer),
            DiveComputerControls,
            'open merge picker',
          ),
        ),
      ],
    );
  }
}
