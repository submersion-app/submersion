import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings for the post-dive safety review: master toggle, per-rule
/// visibility toggles, and a manual backfill over the whole logbook.
class SafetySettingsPage extends ConsumerStatefulWidget {
  const SafetySettingsPage({super.key});

  @override
  ConsumerState<SafetySettingsPage> createState() => _SafetySettingsPageState();
}

class _SafetySettingsPageState extends ConsumerState<SafetySettingsPage> {
  static final _log = LoggerService.forClass(_SafetySettingsPageState);

  /// Dives per bulk-dismiss write. The repository chunks its own SQL; this is
  /// purely how often the progress bar advances on a large logbook.
  static const int _dismissChunk = 50;

  bool _analyzing = false;
  int _analyzeDone = 0;
  int _analyzeTotal = 0;
  bool _dismissing = false;
  int _dismissDone = 0;
  int _dismissTotal = 0;

  /// Both long-running actions write over the whole logbook, so each locks the
  /// page while it runs rather than interleaving with the other.
  bool get _busy => _analyzing || _dismissing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final enabled = settings.safetyReviewEnabled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetySettings_title)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.safetySettings_masterToggle),
            subtitle: Text(l10n.safetySettings_masterToggle_subtitle),
            value: enabled,
            // Locked during a backfill sweep: toggling off mid-run would leave
            // the progress UI counting to a misleading "Analysis complete".
            onChanged: _busy
                ? null
                : (value) => notifier.setSafetyReviewEnabled(value),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.safetySettings_rulesHeader,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          for (final rule in SafetyRuleId.values)
            SwitchListTile(
              title: Text(_ruleLabel(l10n, rule)),
              value: !settings.safetyReviewDisabledRules.contains(rule.dbValue),
              // Same gating as the master toggle: keep the active rule set
              // fixed while a sweep is computing over it.
              onChanged: enabled && !_busy
                  ? (value) => notifier.setSafetyRuleEnabled(rule, value)
                  : null,
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.safetySettings_noFlyHeader,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<NoFlyPreset>(
              segments: [
                ButtonSegment(
                  value: NoFlyPreset.standard,
                  label: Text(l10n.safetySettings_noFlyPreset_standard),
                ),
                ButtonSegment(
                  value: NoFlyPreset.strict,
                  label: Text(l10n.safetySettings_noFlyPreset_strict),
                ),
              ],
              selected: {settings.noFlyPreset},
              onSelectionChanged: (selection) =>
                  notifier.setNoFlyPreset(selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.safetySettings_noFlyPreset_subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.manage_search),
            title: Text(l10n.safetySettings_analyzeAll),
            subtitle: _analyzing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.safetySettings_analyzeAll_progress(
                          _analyzeDone,
                          _analyzeTotal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _analyzeTotal == 0
                            ? null
                            : _analyzeDone / _analyzeTotal,
                      ),
                    ],
                  )
                : Text(l10n.safetySettings_analyzeAll_subtitle),
            enabled: enabled && !_busy,
            onTap: enabled && !_busy ? _analyzeAllDives : null,
          ),
          ListTile(
            leading: const Icon(Icons.done_all),
            title: Text(l10n.safetySettings_dismissAll),
            subtitle: _dismissing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.safetySettings_dismissAll_progress(
                          _dismissDone,
                          _dismissTotal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _dismissTotal == 0
                            ? null
                            : _dismissDone / _dismissTotal,
                      ),
                    ],
                  )
                : Text(l10n.safetySettings_dismissAll_subtitle),
            enabled: enabled && !_busy,
            onTap: enabled && !_busy ? _dismissAllFindings : null,
          ),
        ],
      ),
    );
  }

  String _ruleLabel(AppLocalizations l10n, SafetyRuleId rule) {
    return switch (rule) {
      SafetyRuleId.rapidAscent => l10n.safetySettings_rule_rapidAscent,
      SafetyRuleId.missedDecoStop => l10n.safetySettings_rule_missedDecoStop,
      SafetyRuleId.omittedSafetyStop =>
        l10n.safetySettings_rule_omittedSafetyStop,
      SafetyRuleId.sawtoothProfile => l10n.safetySettings_rule_sawtoothProfile,
      SafetyRuleId.highSurfaceGf => l10n.safetySettings_rule_highSurfaceGf,
    };
  }

  /// Marks every observation in the active diver's logbook as reviewed.
  ///
  /// Destructive enough to confirm first: it clears the findings badge on
  /// every dive at once. Restoring is per-dive, from that dive's safety review
  /// section, so the dialog says so.
  Future<void> _dismissAllFindings() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.safetySettings_dismissAll_confirmTitle),
        content: Text(l10n.safetySettings_dismissAll_confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.safetySettings_dismissAll_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.safetySettings_dismissAll_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Scoped to the active diver, matching "Analyze all dives", and to the
    // rules that diver has switched on so a hidden rule is never dismissed
    // out from under them.
    final diverId = ref.read(currentDiverIdProvider);
    final enabledRuleIds = enabledSafetyRuleIds(ref.read(settingsProvider));
    setState(() {
      _dismissing = true;
      _dismissDone = 0;
      _dismissTotal = 0;
    });

    var changed = 0;
    var failedDives = 0;
    var listFailed = false;
    try {
      final diveIds = await ref
          .read(diveRepositoryProvider)
          .getOrderedDiveIds(diverId: diverId);
      if (!mounted) return;
      setState(() => _dismissTotal = diveIds.length);

      final repo = ref.read(safetyFindingsRepositoryProvider);
      final now = DateTime.now();
      for (var start = 0; start < diveIds.length; start += _dismissChunk) {
        final end = start + _dismissChunk;
        final stop = end < diveIds.length ? end : diveIds.length;
        final chunk = diveIds.sublist(start, stop);
        try {
          changed += await repo.setDismissedForDives(
            diveIds: chunk,
            dismissed: true,
            enabledRuleIds: enabledRuleIds,
            now: now,
          );
        } catch (error, stackTrace) {
          // One unwritable chunk must not strand the rest of the logbook.
          // Its dives stay undismissed and are counted for the summary.
          failedDives += chunk.length;
          _log.error(
            'Failed to dismiss findings for ${chunk.length} dives',
            error: error,
            stackTrace: stackTrace,
          );
        }
        // Leaving the page ends the run. Unlike the analyze sweep this is NOT
        // lossless: dismissal is user intent that nothing recreates, so the
        // dives already written stay dismissed and the rest stay as they were.
        if (!mounted) return;
        setState(() => _dismissDone = stop);
      }
    } catch (error, stackTrace) {
      // The dive list itself failed, so no chunk ever ran and nothing was
      // written. That is retry-safe, unlike a partial run, so say so.
      listFailed = true;
      _log.error(
        'Failed to list dives for bulk dismiss',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }

    if (!mounted) return;
    // Per-dive safetyReviewProvider instances refresh on their own: the
    // findings write ticks watchDiveDetailChanges, which they self-invalidate
    // on. Nothing to invalidate here.
    final message = switch ((listFailed, failedDives)) {
      (true, _) => context.l10n.safetySettings_dismissAll_failed,
      (false, 0) => context.l10n.safetySettings_dismissAll_done(changed),
      (false, final failed) =>
        context.l10n.safetySettings_dismissAll_doneWithErrors(changed, failed),
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _analyzeAllDives() async {
    // Scope the sweep to the active diver's logbook so "Analyze all dives"
    // only touches the current diver's dives, not every diver on the device.
    final diverId = ref.read(currentDiverIdProvider);
    setState(() {
      _analyzing = true;
      _analyzeDone = 0;
      _analyzeTotal = 0;
    });

    final SafetyReviewSweepResult result;
    try {
      result = await ref
          .read(safetyReviewSweepProvider)
          .run(
            diverId: diverId,
            // _analyzeDone tracks dives swept (the progress bar's position),
            // so it advances on failure too; the failure count is surfaced
            // separately when the sweep completes.
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _analyzeDone = done;
                _analyzeTotal = total;
              });
            },
            // Leaving the page ends the sweep, matching the previous
            // `if (!mounted) return;` guard inside the loop.
            isCancelled: () => !mounted,
          );
    } catch (error, stackTrace) {
      // run() catches per-dive analysis failures itself, so reaching here
      // means the sweep could not start at all. Without this the _analyzing
      // flag would stay set, and _busy now disables every control on the page.
      _log.error(
        'Safety review sweep failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.safetySettings_analyzeAll_failed)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _analyzing = false);
    if (result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed == 0
              ? context.l10n.safetySettings_analyzeAll_done
              : context.l10n.safetySettings_analyzeAll_doneWithErrors(
                  result.failed,
                ),
        ),
      ),
    );
  }
}
