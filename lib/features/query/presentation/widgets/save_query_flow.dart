import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

// Named for the flow: its failures come from the diver lookup, the dialog
// or the write, not only the repository.
const _log = LoggerService('SaveQueryFlow');

/// Saves [node] as a [subject] query under a name the diver gives (spec
/// Unit 7). The one save flow every query editor shares: queries are saved
/// per diver, so a missing diver profile says so up front rather than
/// asking for a name and then doing nothing; a failure is logged and says
/// "try again".
Future<void> saveQueryFromEditor(
  BuildContext context,
  WidgetRef ref, {
  required QuerySubject subject,
  required QueryNode node,
}) async {
  try {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (!context.mounted) return;
    if (diverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.query_saveNeedsDiver)),
      );
      return;
    }
    final name = await showSaveQueryDialog(context);
    if (name == null || !context.mounted) return;
    await ref
        .read(savedQueryRepositoryProvider)
        .create(subject: subject, name: name, node: node, diverId: diverId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.query_saved_snackbar(name))),
      );
    }
  } catch (e, st) {
    _log.error('Failed to save query', error: e, stackTrace: st);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.common_error_tryAgain),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
