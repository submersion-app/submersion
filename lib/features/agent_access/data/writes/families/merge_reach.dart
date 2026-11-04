import 'dart:collection';
import 'dart:convert';

import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// What merging [id] of [table] into [intoId] moves, as the app's merges
/// do: every row that links to it, and every row that is part of it,
/// follows the survivor. The basis holds which rows those are, and the
/// survivor's, so a link that comes, goes or moves after the preview
/// refuses the apply even when the counts stay the same.
Future<DeleteReach> linksMoved(
  String table,
  String id,
  String intoId, {
  Set<String> except = const {},
}) async {
  final moved = SplayTreeMap<String, int>.of({
    ...await countUnlinked(table, id, except: except),
    ...await countCascaded(table, id, except: except),
  });
  final rows = await linkRowsDigest(table, id, except: except);
  final survivor = await linkRowsDigest(table, intoId, except: except);
  return DeleteReach(
    moved: moved,
    basis: '${jsonEncode(moved)} $rows $survivor',
  );
}
