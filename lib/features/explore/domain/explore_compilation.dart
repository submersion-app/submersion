import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

enum ChipRef { clause, mention, time }

sealed class ChipPayload {
  const ChipPayload();
}

/// A lowered clause. [value] is in storage units: a double, a List of
/// double (between), a bool (flags), a String or a List of String (enum
/// fields).
class ClauseChip extends ChipPayload {
  final ExploreField field;
  final ClauseOp op;
  final Object value;
  final FieldDimension dimension;
  const ClauseChip({
    required this.field,
    required this.op,
    required this.value,
    required this.dimension,
  });
}

class MentionChip extends ChipPayload {
  final MentionKind kind;
  final NameEntry entry;
  const MentionChip({required this.kind, required this.entry});
}

class TimeChip extends ChipPayload {
  final DateTime? start;
  final DateTime? end;
  const TimeChip({this.start, this.end});
}

/// One chip on the understood row. Removing it drops [ref] at [index] from
/// the ParsedQuery and recompiles; the query is the editable state.
class QueryChip {
  final ChipRef ref;
  final int index;
  final ChipPayload payload;

  /// Whether this chip narrows the subject through its dives (a dive field,
  /// another kind's mention or a period under sites, say) rather than the
  /// subject's own rows. Always false for dives.
  final bool viaDives;
  const QueryChip({
    required this.ref,
    required this.index,
    required this.payload,
    this.viaDives = false,
  });
}

class UnresolvedMention {
  final int index;
  final QueryMention mention;
  final List<NameEntry> candidates;
  const UnresolvedMention({
    required this.index,
    required this.mention,
    required this.candidates,
  });
}

/// A word or clause the compiler could not place. [reason] is one of
/// `unknownField`, `invalid`, `outOfRange`, `noAxis`, `unknownTime`,
/// `aggregateWithScope`, or null for a word the model itself left over.
class UnplacedItem {
  final String text;
  final String? reason;
  const UnplacedItem(this.text, {this.reason});
}

class ExploreCompilation {
  /// What the sentence asks for.
  final ParsedSubject subject;

  /// The sentence as one query rooted at [subject]'s registry entity; null
  /// when nothing was placed.
  final QueryNode? query;

  /// For a non-dive subject, the dive-level part it reaches through its
  /// dives (a dive field, another kind's mention, a period): the ranking
  /// counts these dives. Null for dives, or when the sentence has none.
  final QueryNode? diveScope;
  final List<QueryChip> chips;
  final List<UnresolvedMention> unresolved;
  final List<UnplacedItem> unplaced;
  final List<ChartRequest> charts;
  const ExploreCompilation({
    this.subject = ParsedSubject.dives,
    required this.query,
    this.diveScope,
    required this.chips,
    required this.unresolved,
    required this.unplaced,
    required this.charts,
  });
}
