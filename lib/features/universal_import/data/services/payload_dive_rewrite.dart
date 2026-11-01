import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Turns one dive map into its replacement, or returns it unchanged.
typedef DiveRewrite = Map<String, dynamic> Function(Map<String, dynamic> dive);

/// Dive-level samples [rewriteDivesInSlices] gets through before it hands the
/// event loop back. The surfacing rule costs about 2.5 microseconds a sample
/// in a debug build on a fast desktop, so this leaves room in a frame on a
/// slower device too.
///
/// Counted in samples rather than timed so that a small payload never yields,
/// on any machine. A dive is never split, so one longer than a slice holds the
/// event loop for its own length: about 20 ms for three hours at one sample a
/// second, in that same build.
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
///
/// Once [cancelToken] is cancelled the pass stops at the next slice and gives
/// back [payload] as it was, for a caller that has no more use for the result.
Future<ImportPayload> rewriteDivesInSlices(
  ImportPayload payload,
  DiveRewrite rewrite, {
  int sliceSamples = kDiveRewriteSliceSamples,
  ImportCancellationToken? cancelToken,
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
      if (cancelToken?.isCancelled ?? false) return payload;
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
