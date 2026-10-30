import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_field_labels.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// Owner review of one suggestion (issue #2567): the note, each field
/// before and after, Accept and Dismiss.
Future<void> showSuggestionReviewSheet(
  BuildContext context, {
  required SharedSiteSuggestion suggestion,
  required bool siteGone,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      SuggestionReviewSheet(suggestion: suggestion, siteGone: siteGone),
);

class SuggestionReviewSheet extends ConsumerWidget {
  const SuggestionReviewSheet({
    super.key,
    required this.suggestion,
    required this.siteGone,
  });

  final SharedSiteSuggestion suggestion;
  final bool siteGone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diff = ref.watch(suggestionDiffProvider(suggestion.id));
    final units = UnitFormatter(ref.watch(settingsProvider));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sharedLibrary_inbox_from(
                suggestion.memberName,
                libraryDateLabel(ref, suggestion.createdAt),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (suggestion.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(suggestion.note),
            ],
            const SizedBox(height: 12),
            if (siteGone)
              Text(l10n.sharedLibrary_inbox_siteDeleted)
            else
              diff.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(e.toString()),
                data: (rows) => Flexible(
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: FlexColumnWidth(),
                        2: FlexColumnWidth(),
                      },
                      children: [
                        TableRow(
                          children: [
                            const SizedBox.shrink(),
                            _head(context, l10n.sharedLibrary_inbox_before),
                            _head(context, l10n.sharedLibrary_inbox_after),
                          ],
                        ),
                        for (final e in rows.entries)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  libraryFieldLabel(l10n, e.key),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  libraryFieldValue(
                                    l10n,
                                    units,
                                    e.key,
                                    e.value.$1,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  libraryFieldValue(
                                    l10n,
                                    units,
                                    e.key,
                                    e.value.$2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    if (!demoSealGuard(
                      context,
                      DemoSealedFeature.sharedLibrary,
                    )) {
                      return;
                    }
                    final diverId = await ref.read(
                      validatedCurrentDiverIdProvider.future,
                    );
                    if (diverId == null) return;
                    await ref
                        .read(suggestionServiceProvider)
                        .dismiss(suggestion.id, diverId: diverId);
                    ref.invalidate(
                      incomingSuggestionsProvider(suggestion.libraryId),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(l10n.sharedLibrary_inbox_dismiss),
                ),
                const SizedBox(width: 8),
                if (!siteGone)
                  FilledButton(
                    onPressed: () async {
                      if (!demoSealGuard(
                        context,
                        DemoSealedFeature.sharedLibrary,
                      )) {
                        return;
                      }
                      final diverId = await ref.read(
                        validatedCurrentDiverIdProvider.future,
                      );
                      if (diverId == null) return;
                      await ref
                          .read(suggestionServiceProvider)
                          .accept(suggestion.id, diverId: diverId);
                      ref.invalidate(
                        incomingSuggestionsProvider(suggestion.libraryId),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(l10n.sharedLibrary_inbox_accept),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _head(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.all(4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
