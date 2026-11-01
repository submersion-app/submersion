import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';

/// How long typing rests before a list re-runs its search, as the dive list
/// waits (#2773).
const Duration kEntitySearchDebounce = Duration(milliseconds: 300);

/// The diver opened a list's search row (its search icon, or focusing the
/// field), by the subject the list queries. The row also shows while that
/// list has a query; see `EntitySearchHeader`.
final entitySearchOpenProvider = StateProvider.family<bool, QuerySubject>(
  (ref, subject) => false,
);

/// Set by whatever opens the row and wants the caret in it; the row takes
/// the request (and clears it) once it is built.
final entitySearchFocusPendingProvider =
    StateProvider.family<bool, QuerySubject>((ref, subject) => false);
