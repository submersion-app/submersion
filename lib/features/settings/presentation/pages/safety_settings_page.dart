import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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
  bool _analyzing = false;
  int _analyzeDone = 0;
  int _analyzeTotal = 0;
  int _analyzeFailed = 0;

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
            onChanged: _analyzing
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
              onChanged: enabled && !_analyzing
                  ? (value) => notifier.setSafetyRuleEnabled(rule, value)
                  : null,
            ),
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
            enabled: enabled && !_analyzing,
            onTap: enabled && !_analyzing ? _analyzeAllDives : null,
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

  Future<void> _analyzeAllDives() async {
    // Scope the sweep to the active diver's logbook so "Analyze all dives"
    // only touches the current diver's dives, not every diver on the device.
    final diverId = ref.read(currentDiverIdProvider);
    final diveIds = await ref
        .read(diveRepositoryProvider)
        .getOrderedDiveIds(diverId: diverId);
    if (!mounted) return;
    setState(() {
      _analyzing = true;
      _analyzeDone = 0;
      _analyzeTotal = diveIds.length;
      _analyzeFailed = 0;
    });

    for (final diveId in diveIds) {
      if (!mounted) return;
      try {
        // Compute-through-cache: already-analyzed dives return after a cheap
        // marker-row read; only unanalyzed dives run the profile replay.
        await ref.read(safetyReviewProvider(diveId).future);
      } catch (_) {
        // A dive that fails analysis (corrupt profile) must not abort the
        // sweep; it simply stays unanalyzed. Count it so completion can report
        // failures honestly rather than implying every dive was analyzed.
        _analyzeFailed++;
      }
      if (!mounted) return;
      // _analyzeDone tracks dives swept (the progress bar's position), so it
      // advances on failure too; the failure count is surfaced separately.
      setState(() => _analyzeDone++);
    }

    if (!mounted) return;
    final failed = _analyzeFailed;
    setState(() => _analyzing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? context.l10n.safetySettings_analyzeAll_done
              : context.l10n.safetySettings_analyzeAll_doneWithErrors(failed),
        ),
      ),
    );
  }
}
