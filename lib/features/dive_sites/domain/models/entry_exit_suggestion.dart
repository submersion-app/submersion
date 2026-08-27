import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// The entry/exit pairing most often logged at a site, offered to fill that
/// site's own empty entry and exit method fields (issue #1104).
class EntryExitSuggestion extends Equatable {
  const EntryExitSuggestion({
    required this.entry,
    required this.exit,
    required this.count,
  });

  final EntryMethod entry;

  /// Null when the logged dives record no exit method of their own.
  final EntryMethod? exit;

  /// How many dives at this site record the pairing.
  final int count;

  @override
  List<Object?> get props => [entry, exit, count];
}
