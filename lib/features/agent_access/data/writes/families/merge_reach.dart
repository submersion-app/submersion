import 'dart:collection';
import 'dart:convert';

import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// What merging [id] of [table] into another record moves, as the app's
/// merges do: every row that links to it, and every row that is part of
/// it, follows the survivor. The counts are the basis too, so a link that
/// comes or goes after the preview refuses the apply.
Future<DeleteReach> linksMoved(
  String table,
  String id, {
  Set<String> except = const {},
}) async {
  final moved = SplayTreeMap<String, int>.of({
    ...await countUnlinked(table, id, except: except),
    ...await countCascaded(table, id, except: except),
  });
  return DeleteReach(moved: moved, basis: jsonEncode(moved));
}
