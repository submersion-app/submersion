import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The hydrated dive list narrowed to the ids the compiled filter keeps
/// (#2365), for the table, map and export views.
///
/// [narrowByIds] for dives; its doc states the rules.
AsyncValue<List<Dive>> narrowDivesByIds(
  AsyncValue<List<Dive>> dives,
  AsyncValue<Set<String>?> ids,
) => narrowByIds(dives, ids, (d) => d.id);
