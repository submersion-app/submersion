import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Turns one dive map into its replacement, or returns it unchanged.
typedef DiveRewrite = Map<String, dynamic> Function(Map<String, dynamic> dive);

/// Dive-level samples [rewriteDivesInSlices] gets through before it hands the
/// event loop back. A pass over a dive's profile costs about 2 microseconds a
/// sample at worst, so this stays well inside one frame.
///
/// Counted in samples rather than timed so that a small payload never yields,
/// on any machine.
const int kDiveRewriteSliceSamples = 2000;

/// [payload] with every dive replaced by what [rewrite] returns. The payload is
/// rebuilt, never mutated, and one with no dives comes back as it is.
ImportPayload rewriteDives(ImportPayload payload, DiveRewrite rewrite) {
  final dives = payload.entitiesOf(ImportEntityType.dives);
  if (dives.isEmpty) return payload;
  return _withDives(payload, [for (final dive in dives) rewrite(dive)]);
}

/// [rewriteDives] for a payload on the UI isolate, where a logbook's worth of
/// samples is too much to walk in one go (#3854). Sending the payload to a
/// worker would copy all of it on this isolate first, so the pass stays here
/// and gives way between dives instead.
Future<ImportPayload> rewriteDivesInSlices(
  ImportPayload payload,
  DiveRewrite rewrite, {
  int sliceSamples = kDiveRewriteSliceSamples,
}) async {
  final dives = payload.entitiesOf(ImportEntityType.dives);
  if (dives.isEmpty) return payload;

  final rewritten = <Map<String, dynamic>>[];
  var sliceUsed = 0;
  for (final dive in dives) {
    rewritten.add(rewrite(dive));
    final profile = dive['profile'];
    sliceUsed += 1 + (profile is List ? profile.length : 0);
    if (sliceUsed >= sliceSamples) {
      sliceUsed = 0;
      await Future<void>.delayed(Duration.zero);
    }
  }
  return _withDives(payload, rewritten);
}

ImportPayload _withDives(
  ImportPayload payload,
  List<Map<String, dynamic>> dives,
) => ImportPayload(
  entities: {...payload.entities, ImportEntityType.dives: dives},
  warnings: payload.warnings,
  metadata: payload.metadata,
  sourceDivers: payload.sourceDivers,
);
