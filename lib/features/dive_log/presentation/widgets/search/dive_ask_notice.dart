import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveAskNoticeKey = ValueKey('dive-ask-notice');
const kDiveAskUndoKey = ValueKey('dive-ask-undo');
const kDiveAskOpenListKey = ValueKey('dive-ask-open-list');
const kDiveAskDismissKey = ValueKey('dive-ask-dismiss');

/// What an Ask did (#2773): the words it could not use, each name it
/// could not pin down (tap to pick), Undo, and for a sentence about sites,
/// gear and the like that still needs the diver, Open in list.
class DiveAskNotice extends ConsumerWidget {
  const DiveAskNotice({
    super.key,
    required this.onUndo,
    required this.onOpenList,
  });

  final VoidCallback onUndo;
  final ValueChanged<String> onOpenList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answer = ref.watch(diveAskProvider).answer;
    if (answer == null) return const SizedBox.shrink();
    final compiled = answer.compiled;
    final l10n = context.l10n;
    final notifier = ref.read(diveAskProvider.notifier);
    return Padding(
      key: kDiveAskNoticeKey,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
      // Two lines, not one Row: the actions' localized labels ("Megnyitás a
      // listában", "Visszavonás") can fill a phone's width on their own.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                answer.needsAttention
                    ? l10n.diveLog_ask_couldNotUse
                    : l10n.diveLog_ask_asked(answer.sentence),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final u in compiled.unresolved)
                ActionChip(
                  avatar: const Icon(Icons.help_outline, size: 16),
                  label: Text(u.mention.text),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _pick(context, ref, u),
                ),
              for (final w in compiled.unplaced)
                _UnplacedChip(text: w.text, reason: _reason(l10n, w.reason)),
              // Nothing applied and nothing listed as left over: the
              // whole sentence went unused.
              if (compiled.query == null &&
                  compiled.unplaced.isEmpty &&
                  compiled.unresolved.isEmpty)
                Chip(
                  label: Text(answer.sentence),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (compiled.subject != ParsedSubject.dives &&
                    compiled.query != null)
                  TextButton(
                    key: kDiveAskOpenListKey,
                    onPressed: () {
                      final route = notifier.openAnswerList();
                      if (route != null) onOpenList(route);
                    },
                    child: Text(l10n.explore_handoff_list),
                  ),
                TextButton(
                  key: kDiveAskUndoKey,
                  onPressed: onUndo,
                  child: Text(l10n.diveLog_search_undo),
                ),
                IconButton(
                  key: kDiveAskDismissKey,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: notifier.dismiss,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _reason(AppLocalizations l10n, String? reason) =>
      switch (reason) {
        'invalid' => l10n.explore_unplaced_reason_invalid,
        'noAxis' => l10n.explore_unplaced_reason_noAxis,
        'outOfRange' => l10n.explore_unplaced_reason_outOfRange,
        'unknownField' => l10n.explore_unplaced_reason_unknownField,
        'unknownTime' => l10n.explore_unplaced_reason_unknownTime,
        'aggregateWithScope' => l10n.explore_unplaced_reason_aggregateWithScope,
        _ => null,
      };

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    UnresolvedMention u,
  ) async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<NameEntry>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l10n.explore_pickCandidate_title(u.mention.text)),
            ),
            if (u.candidates.isEmpty)
              ListTile(subtitle: Text(l10n.explore_unresolved_noCandidates)),
            for (final c in u.candidates)
              ListTile(
                title: Text(c.label),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      ref.read(diveAskProvider.notifier).resolveWith(u.index, chosen);
    }
  }
}

/// One word the compiler could not place, with its reason as a tooltip
/// when it has one (the model's own leftovers have none).
class _UnplacedChip extends StatelessWidget {
  const _UnplacedChip({required this.text, this.reason});

  final String text;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final chip = Chip(label: Text(text), visualDensity: VisualDensity.compact);
    final message = reason;
    return message == null ? chip : Tooltip(message: message, child: chip);
  }
}
