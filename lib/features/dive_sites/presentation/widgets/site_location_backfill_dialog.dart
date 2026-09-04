import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/place_name_language_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Seconds per site for the estimate: up to two Nominatim requests (address
/// layer, then natural layer), one second apart. On mobile the address may
/// come from the platform geocoder instead, so this is an upper bound.
const int _secondsPerSite = 2;

/// The bulk location-lookup flow (issue #1187): count, confirm, run with a
/// progress dialog, summarise in a snackbar.
///
/// [mode] decides both what the run writes and the copy: filling in the
/// blanks, or looking every site up again to bring its place names back into
/// one language.
Future<void> showSiteLocationBackfillFlow(
  BuildContext context,
  WidgetRef ref, {
  required SiteLocationLookupMode mode,
}) async {
  final l10n = context.l10n;
  final notifier = ref.read(siteLocationBackfillProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final refreshing = mode == SiteLocationLookupMode.refreshAll;

  // A run already in progress (the progress dialog was popped by a system
  // back gesture, say) is shown again rather than asked about twice.
  if (ref.read(siteLocationBackfillProvider) is BackfillRunning) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BackfillProgressDialog(mode: mode),
    );
    return;
  }

  // The candidates are listed once here: the count drives the confirmation
  // copy and the same list is then handed to the run, so a large site list is
  // not read and mapped twice.
  final candidates = await notifier.findCandidates(mode);
  final count = candidates.length;
  if (!context.mounted) return;
  if (count == 0) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          refreshing
              ? l10n.diveSites_refresh_nothing
              : l10n.diveSites_backfill_nothingToFill,
        ),
      ),
    );
    return;
  }

  final minutes = ((count * _secondsPerSite) / 60).ceil();
  final language = placeNameLanguageLabel(ref.read(placeNameLanguageProvider));
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        refreshing
            ? l10n.diveSites_refresh_confirm_title
            : l10n.diveSites_backfill_confirm_title,
      ),
      content: Text(
        refreshing
            ? l10n.diveSites_refresh_confirm_body(count, language, minutes)
            : l10n.diveSites_backfill_confirm_body(count, minutes),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.diveSites_backfill_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.diveSites_backfill_confirm_start),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // No reset here: start() is the only guard against overlapping runs.
  final run = notifier.start(mode, targets: candidates);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BackfillProgressDialog(mode: mode),
  );
  await run;
  if (!context.mounted) return;

  final state = ref.read(siteLocationBackfillProvider);
  if (state is! BackfillFinished) return;
  final summary = state.summary;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        summary.offline
            ? l10n.diveSites_backfill_offline
            : l10n.diveSites_backfill_summary(
                summary.updated,
                summary.unchanged,
                summary.failed,
              ),
      ),
    ),
  );
  notifier.reset();
}

/// Watches the run and closes itself when it finishes.
class _BackfillProgressDialog extends ConsumerWidget {
  const _BackfillProgressDialog({required this.mode});

  /// The mode this dialog was opened for, used until the run reports its
  /// own, which is the one that matters when the dialog is reopened over a
  /// run started from the other menu entry.
  final SiteLocationLookupMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(siteLocationBackfillProvider);

    ref.listen<BackfillState>(siteLocationBackfillProvider, (_, next) {
      if (next is BackfillFinished && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    if (state is BackfillFinished) {
      // The run finished before this dialog's first listen could fire.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    final running = state is BackfillRunning ? state : null;
    final total = running?.total ?? 0;
    final done = running?.done ?? 0;
    return AlertDialog(
      title: Text(
        (running?.mode ?? mode) == SiteLocationLookupMode.refreshAll
            ? l10n.diveSites_refresh_progress_title
            : l10n.diveSites_backfill_progress_title,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: total == 0 ? null : done / total),
          const SizedBox(height: 12),
          Text(l10n.diveSites_backfill_progress_count(done, total)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              ref.read(siteLocationBackfillProvider.notifier).cancel(),
          child: Text(l10n.diveSites_backfill_cancel),
        ),
      ],
    );
  }
}
