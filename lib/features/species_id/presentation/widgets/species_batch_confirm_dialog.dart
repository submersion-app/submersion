import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/features/species_id/domain/entities/species_batch.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// More items than this and the confirmation says the run takes a while.
const int kSpeciesBatchLongRun = 500;

/// What the diver chose in [SpeciesBatchConfirmDialog].
typedef SpeciesBatchChoice = ({SpeciesBatchPlan plan, bool onDeviceOnly});

/// The confirmation before Find species over many dives (issue #5127). It
/// opens at once and counts while it shows, chunk by chunk from [plans];
/// Cancel stops the counting. Pops a [SpeciesBatchChoice], or null.
class SpeciesBatchConfirmDialog extends StatefulWidget {
  const SpeciesBatchConfirmDialog({
    super.key,
    required this.plans,
    required this.diveCount,
  });

  /// The plan as it grows; the last one is whole.
  final Stream<SpeciesBatchPlan> plans;

  /// Dives asked about, for the counting line.
  final int diveCount;

  @override
  State<SpeciesBatchConfirmDialog> createState() =>
      _SpeciesBatchConfirmDialogState();
}

class _SpeciesBatchConfirmDialogState extends State<SpeciesBatchConfirmDialog> {
  StreamSubscription<SpeciesBatchPlan>? _counting;
  SpeciesBatchPlan _plan = const SpeciesBatchPlan();
  var _counted = false;
  Object? _failure;
  var _onDeviceOnly = false;

  @override
  void initState() {
    super.initState();
    _counting = widget.plans.listen(
      (plan) => setState(() => _plan = plan),
      onError: (Object e) => setState(() => _failure = e),
      onDone: () => setState(() => _counted = true),
    );
  }

  @override
  void dispose() {
    unawaited(_counting?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = _plan;
    final canStart = _counted && _failure == null && !plan.isEmpty;
    return AlertDialog(
      title: Text(l10n.speciesReview_find),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_failure != null)
              Text(l10n.speciesBatch_countFailed)
            else if (!_counted)
              Row(
                key: const ValueKey('species_batch_counting'),
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.speciesBatch_counting(
                        plan.divesAsked,
                        widget.diveCount,
                      ),
                    ),
                  ),
                ],
              )
            else if (plan.isEmpty)
              Text(
                l10n.speciesBatch_nothingToDo,
                key: const ValueKey('species_batch_nothing'),
              )
            else ...[
              Text(
                plan.toLookAt == 0
                    ? l10n.speciesBatch_applyOnly(
                        l10n.speciesBatch_dives(plan.dives.length),
                      )
                    : l10n.speciesBatch_toLookAt(
                        l10n.speciesBatch_dives(plan.dives.length),
                        l10n.speciesBatch_items(plan.toLookAt),
                      ),
                key: const ValueKey('species_batch_summary'),
              ),
              if (plan.notOnDevice > 0) ...[
                const SizedBox(height: 12),
                Text(l10n.speciesBatch_notOnDevice(plan.notOnDevice)),
                RadioGroup<bool>(
                  groupValue: _onDeviceOnly,
                  onChanged: (v) => setState(() => _onDeviceOnly = v ?? false),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<bool>(
                        key: const ValueKey('species_batch_download'),
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        title: Text(l10n.speciesBatch_downloadThem),
                      ),
                      RadioListTile<bool>(
                        key: const ValueKey('species_batch_on_device_only'),
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        title: Text(l10n.speciesBatch_onDeviceOnly),
                      ),
                    ],
                  ),
                ),
              ],
              if (plan.toLookAt > kSpeciesBatchLongRun) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.speciesBatch_takesAWhile,
                  key: const ValueKey('species_batch_takes_a_while'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (_counted && (plan.isEmpty || _failure != null))
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_action_ok),
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('species_batch_start'),
            onPressed: canStart
                ? () => Navigator.of(context).pop<SpeciesBatchChoice>((
                    plan: plan,
                    onDeviceOnly: plan.notOnDevice > 0 && _onDeviceOnly,
                  ))
                : null,
            child: Text(l10n.speciesBatch_start),
          ),
        ],
      ],
    );
  }
}
