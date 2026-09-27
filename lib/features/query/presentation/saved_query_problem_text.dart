import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
