import 'package:submersion/core/query/domain/query_subject.dart';

/// The subjects a query may root at: the registry's list subjects, which
/// `QuerySubject` declares first. The query tool and the query-language
/// resource both read this list, so they can never disagree.
final List<QuerySubject> kQueryRoots = List.unmodifiable(
  QuerySubject.values.take(9),
);
