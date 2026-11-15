import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/raw_dive_data_discard.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

final _log = LoggerService.forClass(RawDiveDataPage);

/// Settings > Data > Data tools > Raw dive computer data (issue #4590): how
/// much raw download data the library keeps, in total and per computer, with
/// the actions to discard it all or one computer's (issue #1376). Covers
/// every diver, as a discard does.
class RawDiveDataPage extends ConsumerWidget {
  const RawDiveDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Logged where a count fails, not in build: a rebuild while it stays
    // failed would log the same error again.
    void logFailure(AsyncValue<Object?>? previous, AsyncValue<Object?> next) {
      if (!next.hasError || (previous?.hasError ?? false)) return;
      _log.error(
        'Could not count the raw dive computer data',
        error: next.error,
        stackTrace: next.stackTrace,
      );
    }

    ref.listen(rawDiveDataUsageProvider, logFailure);
    ref.listen(rawDiveDataByComputerProvider, logFailure);
    final total = ref.watch(rawDiveDataUsageProvider);
    final byComputer = ref.watch(rawDiveDataByComputerProvider);
    final Widget body;
    if (total.hasError || byComputer.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.common_error_tryAgain),
        ),
      );
    } else if (total.value case final usage? when byComputer.value != null) {
      body = _Overview(total: usage, byComputer: byComputer.value!);
    } else {
      body = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.diveComputer_rawData_tileTitle)),
      body: body,
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.total, required this.byComputer});

  final RawDiveDataUsage total;
  final List<ComputerRawDiveDataUsage> byComputer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (total.diveCount == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [Text(l10n.settings_rawDiveData_none)],
      );
    }
    final size = formatBytes(total.storedBytes);
    final error = theme.colorScheme.error;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.diveComputer_rawData_tileSubtitle(total.diveCount, size),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('raw_dive_data_discard_all'),
            style: OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error),
            ),
            onPressed: () => confirmAndDiscardRawDiveData(
              context,
              ref,
              message: l10n.diveComputer_rawData_discardAllMessage(
                total.diveCount,
                size,
              ),
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.settings_rawDiveData_discardAll),
          ),
        ),
        if (byComputer.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.settings_rawDiveData_byComputer,
            style: theme.textTheme.labelLarge,
          ),
          for (final computer in byComputer)
            _computerTile(context, ref, computer),
        ],
      ],
    );
  }

  Widget _computerTile(
    BuildContext context,
    WidgetRef ref,
    ComputerRawDiveDataUsage computer,
  ) {
    final l10n = context.l10n;
    final id = computer.computerId;
    // A computer with no name, maker or model has an empty display name;
    // it is still discardable by its id, under the unknown label.
    final name = computer.name;
    final label = name == null || name.isEmpty
        ? l10n.settings_rawDiveData_unknownComputer
        : name;
    final usage = Text(
      l10n.settings_rawDiveData_computerUsage(
        computer.diveCount,
        formatBytes(computer.storedBytes),
      ),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.watch_outlined),
      title: Text(label),
      // The unknown row has no computer to discard by; Discard all clears it.
      subtitle: id == null
          ? usage
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                usage,
                TileSubtitleAction(
                  actionKey: ValueKey('raw_dive_data_discard_$id'),
                  label: l10n.diveComputer_rawData_discardAction,
                  semanticsLabel: l10n
                      .settings_rawDiveData_discardComputerSemantics(label),
                  onPressed: () => confirmAndDiscardRawDiveData(
                    context,
                    ref,
                    computerId: id,
                    message: l10n.diveComputer_rawData_discardComputerMessage(
                      label,
                      computer.diveCount,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
