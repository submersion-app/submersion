import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows that a parse is running and offers to stop it.
///
/// A batch shows how far through its files it is. A single file has no such
/// count, so its bar runs indeterminate.
class ParseProgress extends ConsumerWidget {
  const ParseProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (current, total) = ref.watch(
      universalImportNotifierProvider.select(
        (s) => (s.parseCurrent, s.parseTotal),
      ),
    );
    final l10n = context.l10n;
    final isBatch = total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: isBatch ? current / total : null),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                l10n.universalImport_triage_parsing(
                  isBatch ? current : 1,
                  isBatch ? total : 1,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(universalImportNotifierProvider.notifier)
                  .cancelParse(),
              child: Text(l10n.universalImport_triage_cancelParsing),
            ),
          ],
        ),
      ],
    );
  }
}
