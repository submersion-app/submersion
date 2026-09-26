import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

enum ChipRef { clause, mention, time }

sealed class ChipPayload {
  const ChipPayload();
}

/// A lowered clause. [value] is in storage units: a double, a List of
/// double (between), a bool (flags), a String or a List of String (enum
/// fields).
class ClauseChip extends ChipPayload {
  final ExploreDiveField field;
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
  const QueryChip({
    required this.ref,
    required this.index,
    required this.payload,
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
/// `subjectNotSupported`, or null for a word the model itself left over.
class UnplacedItem {
  final String text;
  final String? reason;
  const UnplacedItem(this.text, {this.reason});
}

class CompiledQuery {
  final DiveFilterState filter;
  final List<QueryChip> chips;
  final List<UnresolvedMention> unresolved;
  final List<UnplacedItem> unplaced;
  final List<ChartRequest> charts;
  const CompiledQuery({
    required this.filter,
    required this.chips,
    required this.unresolved,
    required this.unplaced,
    required this.charts,
  });
}
