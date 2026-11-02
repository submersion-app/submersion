import 'package:flutter/material.dart';

import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Explains why [load] cannot be applied: the same wording as the Manage
/// page, in the diver's language, under the query's name.
void showSavedQueryProblem(BuildContext context, SavedQueryLoad load) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            load.saved.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(savedQueryProblemText(context.l10n, load)!),
        ],
      ),
    ),
  );
}

/// Why a saved query cannot be used as it stands, in the diver's language,
/// or null when nothing is wrong. Shared by the Manage page and the chip
/// row so both say the same thing. The loader's English [SavedQueryLoad]
/// detail is shown only where it is a name the diver or the app chose
/// (a list or a path), never where it is an error message.
String? savedQueryProblemText(AppLocalizations l10n, SavedQueryLoad load) =>
    switch (load.problem) {
      null => null,
      SavedQueryProblem.unresolvedRef => l10n.savedQueries_problem_unresolved(
        load.detail ?? '',
      ),
      SavedQueryProblem.unreadable => l10n.savedQueries_problem_unreadable,
      SavedQueryProblem.invalid => l10n.savedQueries_problem_invalid(
        load.error == null
            ? load.detail ?? ''
            : describeQueryError(l10n, load.error!),
      ),
      SavedQueryProblem.unknownSubject =>
        l10n.savedQueries_problem_unknownSubject(load.detail ?? ''),
    };
