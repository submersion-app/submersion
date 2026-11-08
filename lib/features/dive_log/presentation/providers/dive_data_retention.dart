import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/providers/retain_until_idle.dart';

/// How long a dive's decoded data stays in memory after nothing uses it.
///
/// Long enough that stepping back and forth through a repetitive dive day, or
/// returning to a dive from the list, reuses its profile and the residual
/// chain behind its analysis rather than replaying every earlier dive again.
const diveDataRetention = Duration(minutes: 5);

/// Holds a per-dive family entry for [diveDataRetention] after its last
/// listener leaves, then lets it auto-dispose (#4254).
///
/// Every family keyed per dive (or per dive and source) that holds decoded
/// samples, or the analysis replayed from them, calls this as the first
/// statement of its build and is declared `autoDispose`. So does every family
/// that watches one: a keep-forever watcher would hold its dependency alive
/// for the whole session. Before this, each dive opened in a session kept its
/// full detail dive, source buckets, analysis dive and `ProfileAnalysis`
/// (16 compartment states per sample) until the app quit.
/// `test/architecture/dive_provider_disposal_test.dart` lists the families.
void retainDiveData(Ref ref) => retainUntilIdle(ref, diveDataRetention);
