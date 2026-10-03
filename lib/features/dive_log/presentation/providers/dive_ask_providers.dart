import 'dart:async';
import 'dart:convert';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/domain/entity_resolver.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/explore_grounding.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/explore_handoff.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// One answered sentence, kept while its notice shows (#2773).
class AskAnswer {
  const AskAnswer({
    required this.sentence,
    required this.parsed,
    required this.compiled,
    required this.previousQuery,
  });

  final String sentence;
  final ParsedQuery parsed;
  final ExploreCompilation compiled;

  /// The dive list's query before the Ask; Undo writes it back.
  final QueryNode? previousQuery;

  /// Nothing was applied, words the compiler could not place, or a name
  /// with several matches.
  bool get needsAttention =>
      compiled.query == null ||
      compiled.unplaced.isNotEmpty ||
      compiled.unresolved.isNotEmpty;
}

class AskState {
  const AskState({this.running = false, this.error, this.answer});
  final bool running;
  final NlError? error;
  final AskAnswer? answer;
}

/// Ask from the dive search row (#2773, Explore's sentence flow): the
/// on-device model reads the sentence, the Explore compiler turns it into a
/// query, and a dive answer replaces only the list's query while another
/// subject's answer goes to that subject's list.
class DiveAskNotifier extends StateNotifier<AskState> {
  DiveAskNotifier(this._ref) : super(const AskState()) {
    // The notice belongs to its answer: once the dive query moves away
    // from it (a chip removed, typing, Clear all), Undo would restore the
    // wrong thing, so the notice goes. An answer that placed nothing left
    // the query as it was, so that query is the one to watch.
    _ref.listen<DiveFilterState>(diveFilterProvider, (_, next) {
      final answer = state.answer;
      if (answer == null || answer.compiled.subject != ParsedSubject.dives) {
        return;
      }
      final applied = answer.compiled.query ?? answer.previousQuery;
      if (next.query != applied) dismiss();
    });
  }

  final Ref _ref;
  static const _log = LoggerService('DiveAsk');

  /// Bumped by every request and by [cancel]; a reply publishes only while
  /// its request is still the latest.
  int _request = 0;
  bool _prepared = false;

  /// Runs [sentence]. Returns the route of the list it handed off to, or
  /// null when the answer stays here (or failed, or was superseded).
  Future<String?> ask(String sentence) async {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return null;
    final request = ++_request;
    state = const AskState(running: true);
    try {
      // Whose question this is, fixed now: a diver switch while the model
      // works must not file it under the next diver.
      final diverId = await _askingDiver();
      if (request != _request) return null;
      final locale = _ref.read(localeProvider);
      final json = await _ref
          .read(nlEngineProvider)
          .compile(trimmed, localeTag: locale);
      if (request != _request) return null;
      // Only what the sentence says: the model copies the prompt's examples
      // into sentences that never asked for them (#2838).
      final parsed = groundedIn(
        ParsedQuery.fromDecoded(jsonDecode(json)),
        trimmed,
        locale: exploreLocaleTag(
          locale,
          _ref.read(exploreDeviceLocaleProvider),
        ),
      );
      final names = await _ref.read(exploreNameIndexProvider.future);
      if (request != _request) return null;
      final route = _publish(
        AskAnswer(
          sentence: trimmed,
          parsed: parsed,
          compiled: _compile(parsed, names),
          // What is applied just before the answer, not when the Ask
          // started: a chip removed meanwhile must not come back on Undo.
          previousQuery: _ref.read(diveFilterProvider).query,
        ),
        handOff: true,
      );
      // Not awaited: remembering the sentence must not hold up the answer
      // or a handoff, and it already logs its own failure.
      unawaited(_recordRecent(trimmed, locale, parsed, diverId ?? ''));
      return route;
    } on NlException catch (e) {
      _fail(request, e.error);
    } on QuerySchemaException {
      _fail(request, NlError.schemaMismatch);
    } on FormatException {
      _fail(request, NlError.schemaMismatch);
    } catch (e, stackTrace) {
      // Anything else (the name index failing to build, a database error)
      // must still end the run, or the row spins with nothing saying why.
      _log.error('Ask failed', error: e, stackTrace: stackTrace);
      _fail(request, NlError.unknown);
    }
    return null;
  }

  /// A recent asked sentence: its stored parse when the current prompt
  /// wrote it (no model call), otherwise the model again, so an older
  /// parse's invented period is not replayed (#2838).
  Future<String?> replay(RecentQuery recent) async {
    final parsed = recent.parsed;
    if (parsed == null) return ask(recent.sentence);
    final request = ++_request;
    state = const AskState(running: true);
    try {
      final names = await _ref.read(exploreNameIndexProvider.future);
      if (request != _request) return null;
      return _publish(
        AskAnswer(
          sentence: recent.sentence,
          parsed: parsed,
          compiled: _compile(parsed, names),
          previousQuery: _ref.read(diveFilterProvider).query,
        ),
        handOff: true,
      );
    } catch (e, stackTrace) {
      _log.error('Replaying a recent failed', error: e, stackTrace: stackTrace);
      _fail(request, NlError.unknown);
      return null;
    }
  }

  /// Pins mention [mentionIndex] to [entry] and recompiles. The label goes
  /// into the text so the chip reads right; the identity rides along
  /// because two entities can share a label exactly.
  void resolveWith(int mentionIndex, NameEntry entry) {
    final answer = state.answer;
    if (answer == null || mentionIndex >= answer.parsed.mentions.length) {
      return;
    }
    final mentions = [...answer.parsed.mentions];
    mentions[mentionIndex] = QueryMention(
      kind: mentionKindOf(entry.target),
      text: entry.label,
      identity: entry.identity,
    );
    final parsed = ParsedQuery(
      subject: answer.parsed.subject,
      clauses: answer.parsed.clauses,
      mentions: mentions,
      time: answer.parsed.time,
      unplaced: answer.parsed.unplaced,
    );
    final names = _ref.read(exploreNameIndexProvider).value ?? NameIndex.empty;
    _publish(
      AskAnswer(
        sentence: answer.sentence,
        parsed: parsed,
        compiled: _compile(parsed, names),
        previousQuery: answer.previousQuery,
      ),
      handOff: false,
    );
  }

  /// Writes the dive query from before the Ask back and returns the
  /// sentence for the field; null with nothing to undo.
  String? undo() {
    final answer = state.answer;
    if (answer == null) return null;
    state = const AskState();
    if (answer.compiled.subject == ParsedSubject.dives) {
      final notifier = _ref.read(diveFilterProvider.notifier);
      notifier.state = notifier.state.copyWith(
        query: answer.previousQuery,
        clearQuery: answer.previousQuery == null,
      );
    }
    return answer.sentence;
  }

  /// Hands the kept non-dive answer to its list; returns the route.
  String? openAnswerList() {
    final answer = state.answer;
    final node = answer?.compiled.query;
    if (answer == null ||
        node == null ||
        answer.compiled.subject == ParsedSubject.dives) {
      return null;
    }
    state = const AskState();
    return writeSubjectHandoff(_ref, answer.compiled.subject, node);
  }

  /// Hides the notice; a running Ask goes on.
  void dismiss() => state = AskState(running: state.running);

  /// Drops an Ask still waiting on the model (the diver typed on) and its
  /// error; a published answer stays.
  void cancel() {
    _request++;
    if (state.running || state.error != null) {
      state = AskState(answer: state.answer);
    }
  }

  /// Drops everything: the search row was closed or cleared.
  void reset() {
    _request++;
    state = const AskState();
  }

  /// Warms the model up once it can answer, so the first Ask is not the
  /// cold start. Not before: a warm-up spent on a model still to download
  /// would never be repeated once it arrives.
  void prepare() {
    if (_prepared || !_ref.read(exploreEnabledProvider)) return;
    _prepared = true;
    _ref.read(nlEngineProvider).prepare().catchError((Object _) {});
  }

  ExploreCompilation _compile(ParsedQuery parsed, NameIndex names) =>
      ExploreCompiler.compile(
        parsed,
        ExploreCompilerContext(
          units: _ref.read(queryUnitPrefsProvider),
          names: names,
          now: DateTime.now(),
        ),
      );

  /// Applies [answer]; returns a route when it handed off at once.
  String? _publish(AskAnswer answer, {required bool handOff}) {
    final compiled = answer.compiled;
    if (compiled.subject == ParsedSubject.dives) {
      final query = compiled.query;
      if (query != null) {
        final notifier = _ref.read(diveFilterProvider.notifier);
        notifier.state = notifier.state.copyWith(query: query);
      }
      // After the write: the listener above clears an older notice.
      state = AskState(answer: answer);
      return null;
    }
    final query = compiled.query;
    if (handOff && query != null && !answer.needsAttention) {
      state = const AskState();
      return writeSubjectHandoff(_ref, compiled.subject, query);
    }
    state = AskState(answer: answer);
    return null;
  }

  void _fail(int request, NlError error) {
    if (request != _request) return;
    state = AskState(error: error);
  }

  /// The active diver, only to file the sentence under; a lookup failure
  /// files it under no diver rather than failing an answer.
  Future<String?> _askingDiver() async {
    try {
      return await _ref.read(validatedCurrentDiverIdProvider.future);
    } catch (e, stackTrace) {
      _log.warning(
        'No diver for a recent sentence',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Remembering the sentence is a convenience: a failed write must not
  /// turn an answer the diver can see into an error.
  Future<void> _recordRecent(
    String sentence,
    String locale,
    ParsedQuery parsed,
    String diverId,
  ) async {
    try {
      await _ref.read(recentQueryRecorderProvider)(
        sentence,
        locale,
        parsed,
        diverId,
      );
    } catch (e, stackTrace) {
      _log.warning(
        'Could not remember an asked sentence',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final diveAskProvider = StateNotifierProvider<DiveAskNotifier, AskState>(
  (ref) => DiveAskNotifier(ref),
);
