import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../explore/domain/explore_query_parts.dart';

/// Answers every sentence from [replies] (or [json]); [gates] holds back a
/// sentence's answer until the test completes it.
class _Engine implements NlEngine {
  _Engine([this.json = '']);
  final String json;
  final replies = <String, String>{};
  final gates = <String, Completer<String>>{};
  Object? throwing;
  int compileCalls = 0;
  int prepareCalls = 0;

  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) {
    compileCalls++;
    if (throwing != null) return Future.error(throwing!);
    if (gates.containsKey(sentence)) return gates[sentence]!.future;
    return Future.value(replies[sentence] ?? json);
  }
}

const _turtles =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
    '"op":"gt","value":20,"unit":"m","text":"below 20m"}],"mentions":'
    '[{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":["maybe"]}';
const _deep =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
    '"op":"gte","value":40,"unit":"m","text":"deep"}],"mentions":[],"time":null,"unplaced":[]}';
const _nothing =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[],"mentions":[],'
    '"time":null,"unplaced":["fluffy clouds"]}';
const _goodSites =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
    '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,"unplaced":[]}';
const _sitesWithLeftovers =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
    '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,"unplaced":["cosy"]}';

final _bonaire = NameIndex(const [
  NameEntry(
    subject: QuerySubject.sites,
    label: 'Bonaire',
    ids: ['s1', 's2'],
    target: NameTarget.sitePlace,
  ),
]);

/// The active diver, switchable mid-Ask.
final _diver = StateProvider<String?>((ref) => null);

void main() {
  late List<String> recorded;

  ProviderContainer make(
    _Engine engine, {
    Future<NameIndex> Function()? names,
    RecentQueryRecorder? recorder,
    DiveFilterState filter = const DiveFilterState(),
    String locale = 'en',
    Locale device = const Locale('en', 'US'),
  }) {
    recorded = [];
    final c = ProviderContainer(
      overrides: [
        nlEngineProvider.overrideWithValue(engine),
        explorePlatformSupportedProvider.overrideWithValue(true),
        exploreEnabledProvider.overrideWithValue(true),
        localeProvider.overrideWithValue(locale),
        exploreDeviceLocaleProvider.overrideWithValue(() => device),
        queryUnitPrefsProvider.overrideWithValue(
          const UnitPrefs(
            depth: DepthUnit.meters,
            temperature: TemperatureUnit.celsius,
            pressure: PressureUnit.bar,
            weight: WeightUnit.kilograms,
            volume: VolumeUnit.liters,
          ),
        ),
        exploreNameIndexProvider.overrideWith(
          (ref) => names?.call() ?? Future.value(_bonaire),
        ),
        recentQueryRecorderProvider.overrideWithValue(
          recorder ??
              (sentence, locale, parsed, diverId) async =>
                  recorded.add(sentence),
        ),
        diveFilterProvider.overrideWith((ref) => filter),
        _diver.overrideWith((ref) => 'ana'),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => ref.watch(_diver),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  AskState stateOf(ProviderContainer c) => c.read(diveAskProvider);
  DiveAskNotifier askOf(ProviderContainer c) =>
      c.read(diveAskProvider.notifier);
  DiveFilterState filterOf(ProviderContainer c) => c.read(diveFilterProvider);

  test('a dive answer replaces only the query', () async {
    final c = make(
      _Engine(_turtles),
      filter: DiveFilterState(
        favoritesOnly: true,
        axesSuspended: true,
        query: TextNode(['old']),
      ),
    );
    expect(await askOf(c).ask('Turtles below 20m in Bonaire'), isNull);
    final answer = stateOf(c).answer!;
    expect(filterOf(c).query, answer.compiled.query);
    expect(filterOf(c).favoritesOnly, isTrue);
    expect(filterOf(c).axesSuspended, isTrue);
    expect(answer.previousQuery, TextNode(['old']));
    expect(boundOf(answer.compiled, 'depth', QueryOp.gte), 20);
    expect(answer.compiled.unplaced.single.text, 'maybe');
    expect(recorded, ['Turtles below 20m in Bonaire']);
  });

  test(
    'Undo writes the previous query back and returns the sentence',
    () async {
      final c = make(
        _Engine(_turtles),
        filter: DiveFilterState(query: TextNode(['old'])),
      );
      await askOf(c).ask('Turtles below 20m in Bonaire');
      expect(askOf(c).undo(), 'Turtles below 20m in Bonaire');
      expect(filterOf(c).query, TextNode(['old']));
      expect(stateOf(c).answer, isNull);
    },
  );

  // Review Focus 3.
  test('a sentence that places nothing leaves the filter alone', () async {
    final before = DiveFilterState(minDepth: 10, query: TextNode(['reef']));
    final c = make(_Engine(_nothing), filter: before);
    await askOf(c).ask('fluffy clouds');
    expect(filterOf(c), before);
    expect(stateOf(c).answer!.compiled.unplaced.single.text, 'fluffy clouds');
    expect(stateOf(c).answer!.needsAttention, isTrue);
  });

  // Review: a model that places nothing and lists nothing as unplaced
  // still applied nothing, and must say so.
  test(
    'an answer with no query needs the diver even with no leftovers',
    () async {
      const empty =
          '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[],'
          '"mentions":[],"time":null,"unplaced":[]}';
      final before = DiveFilterState(query: TextNode(['reef']));
      final c = make(_Engine(empty), filter: before);
      await askOf(c).ask('show me my best dives');
      expect(filterOf(c), before);
      expect(stateOf(c).answer!.compiled.query, isNull);
      expect(stateOf(c).answer!.needsAttention, isTrue);
    },
  );

  test('another subject with nothing to show hands off at once', () async {
    final c = make(_Engine(_goodSites));
    expect(await askOf(c).ask('sites rated 4'), '/sites');
    expect(c.read(siteFilterProvider).query, isNotNull);
    expect(stateOf(c).answer, isNull);
    expect(filterOf(c), const DiveFilterState());
  });

  test('another subject needing the diver waits for Open in list', () async {
    final c = make(_Engine(_sitesWithLeftovers));
    expect(await askOf(c).ask('cosy sites rated 4'), isNull);
    expect(stateOf(c).answer!.needsAttention, isTrue);
    expect(c.read(siteFilterProvider).query, isNull);
    expect(askOf(c).openAnswerList(), '/sites');
    expect(c.read(siteFilterProvider).query, isNotNull);
    expect(stateOf(c).answer, isNull);
  });

  test('picking between two same-named buddies sticks', () async {
    final twins = NameIndex(const [
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'John Smith',
        ids: ['john-a'],
        target: NameTarget.buddyId,
      ),
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'John Smith',
        ids: ['john-b'],
        target: NameTarget.buddyId,
      ),
    ]);
    const withJohn =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","mentions":'
        '[{"kind":"buddy","text":"John Smith"}],"unplaced":[]}';
    final c = make(
      _Engine(withJohn),
      names: () async => twins,
      filter: DiveFilterState(query: TextNode(['old'])),
    );
    await askOf(c).ask('dives with John Smith');
    expect(stateOf(c).answer!.compiled.unresolved, hasLength(1));
    askOf(c).resolveWith(0, twins.entries[1]);
    expect(
      (conditionsIn(filterOf(c).query, ['buddies'], QueryOp.eq).single.value!
              as RefValue)
          .id,
      'john-b',
    );
    expect(stateOf(c).answer!.compiled.unresolved, isEmpty);
    // Undo still goes back to before the Ask, not to before the pick.
    expect(stateOf(c).answer!.previousQuery, TextNode(['old']));
  });

  test('a pick past the last mention is ignored', () async {
    final c = make(_Engine(_turtles));
    await askOf(c).ask('x');
    final before = filterOf(c);
    askOf(c).resolveWith(99, _bonaire.entries.single);
    expect(filterOf(c), before);
  });

  test(
    'the notice goes once the dive query moves away from the answer',
    () async {
      final c = make(_Engine(_turtles));
      await askOf(c).ask('x');
      expect(stateOf(c).answer, isNotNull);
      final notifier = c.read(diveFilterProvider.notifier);
      notifier.state = notifier.state.copyWith(query: TextNode(['other']));
      expect(stateOf(c).answer, isNull);
    },
  );

  // Code review: an answer that placed nothing leaves the query alone, so
  // only a move of THAT query may take its notice (and Undo) away.
  test('a no-query notice survives other filter changes', () async {
    final c = make(
      _Engine(_nothing),
      filter: DiveFilterState(query: TextNode(['reef'])),
    );
    await askOf(c).ask('fluffy clouds');
    final notifier = c.read(diveFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(axesSuspended: true);
    expect(stateOf(c).answer, isNotNull);
    notifier.state = notifier.state.copyWith(query: TextNode(['wreck']));
    expect(stateOf(c).answer, isNull);
  });

  // Code review: remembering the sentence must not hold up the handoff.
  test('a handoff does not wait for the recent-query write', () async {
    final c = make(
      _Engine(_goodSites),
      recorder: (sentence, locale, parsed, diverId) => Completer<void>().future,
    );
    final route = await askOf(
      c,
    ).ask('sites rated 4').timeout(const Duration(seconds: 2));
    expect(route, '/sites');
  });

  test('an engine error is published, the filter untouched', () async {
    final engine = _Engine()
      ..throwing = const NlException(NlError.contextExceeded);
    final c = make(engine, filter: DiveFilterState(query: TextNode(['old'])));
    expect(await askOf(c).ask('x'), isNull);
    expect(stateOf(c).running, isFalse);
    expect(stateOf(c).error, NlError.contextExceeded);
    expect(filterOf(c).query, TextNode(['old']));
  });

  test('a non-object JSON root is a schema mismatch', () async {
    final c = make(_Engine('[1, 2]'));
    await askOf(c).ask('x');
    expect(stateOf(c).error, NlError.schemaMismatch);
  });

  test('text that is not JSON at all is a schema mismatch', () async {
    final c = make(_Engine('not json'));
    await askOf(c).ask('x');
    expect(stateOf(c).error, NlError.schemaMismatch);
  });

  test('an unexpected failure ends the run with an error', () async {
    final c = make(
      _Engine(_turtles),
      names: () async => throw StateError('index build failed'),
    );
    await askOf(c).ask('x');
    expect(stateOf(c).running, isFalse);
    expect(stateOf(c).error, NlError.unknown);
  });

  test('a failed recent-query write does not hide a good answer', () async {
    final c = make(
      _Engine(_turtles),
      recorder: (sentence, locale, parsed, diverId) async =>
          throw StateError('full'),
    );
    await askOf(c).ask('x');
    expect(stateOf(c).error, isNull);
    expect(stateOf(c).answer, isNotNull);
  });

  test('an empty sentence never reaches the model', () async {
    final engine = _Engine(_turtles);
    final c = make(engine);
    await askOf(c).ask('   ');
    expect(engine.compileCalls, 0);
  });

  test('a slow reply cannot overwrite a newer request', () async {
    final engine = _Engine()
      ..replies['deep dives'] = _deep
      ..gates['first'] = Completer<String>();
    final c = make(engine);
    final first = askOf(c).ask('first');
    await Future<void>.delayed(Duration.zero);
    await askOf(c).ask('deep dives');
    engine.gates['first']!.complete(_turtles);
    await first;
    expect(stateOf(c).answer!.sentence, 'deep dives');
    expect(boundOf(stateOf(c).answer!.compiled, 'depth', QueryOp.gte), 40);
  });

  // Review Focus 1.
  test('cancel drops the answer still on its way', () async {
    final engine = _Engine()..gates['first'] = Completer<String>();
    final c = make(engine, filter: DiveFilterState(query: TextNode(['typed'])));
    final first = askOf(c).ask('first');
    await Future<void>.delayed(Duration.zero);
    expect(stateOf(c).running, isTrue);
    askOf(c).cancel();
    expect(stateOf(c).running, isFalse);
    engine.gates['first']!.complete(_turtles);
    expect(await first, isNull);
    expect(stateOf(c).answer, isNull);
    expect(filterOf(c).query, TextNode(['typed']));
  });

  // Ported with Explore's notifier: the model copies the prompt's examples
  // into sentences that never asked for them (#2838, #2842).
  group('grounding', () {
    const embellished =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":['
        '{"field":"depth","op":"gt","value":20,"unit":"m","text":"below 20m"},'
        '{"field":"waterTemp","op":"lt","value":15,"unit":"c",'
        '"text":"cold-water"}],"mentions":[{"kind":"place","text":"Bonaire"}],'
        '"time":"since 2022","unplaced":[]}';

    test('a filter or year the sentence never said is not applied', () async {
      ParsedQuery? kept;
      final c = make(
        _Engine(embellished),
        recorder: (sentence, locale, parsed, diverId) async => kept = parsed,
      );
      await askOf(c).ask('Turtles below 20m in Bonaire');
      final compiled = stateOf(c).answer!.compiled;
      expect(boundOf(compiled, 'depth', QueryOp.gte), 20);
      expect(boundOf(compiled, 'waterTemp', QueryOp.lte), isNull);
      expect(compiled.chips.map((ch) => ch.ref), isNot(contains(ChipRef.time)));
      // The recent list keeps what the diver saw, not the raw reply.
      expect(kept!.clauses.map((cl) => cl.text), ['below 20m']);
      expect(kept!.time, isNull);
    });

    Future<ExploreCompilation> askOnDevice(
      Locale device,
      String sentence,
    ) async {
      final c = make(_Engine(embellished), locale: 'system', device: device);
      await askOf(c).ask(sentence);
      return stateOf(c).answer!.compiled;
    }

    test('following an English device, invented clauses are dropped', () async {
      final compiled = await askOnDevice(
        const Locale('en', 'US'),
        'Turtles below 20m in Bonaire',
      );
      expect(boundOf(compiled, 'waterTemp', QueryOp.lte), isNull);
    });

    test('following a German device, clauses are kept', () async {
      final compiled = await askOnDevice(
        const Locale('de', 'DE'),
        'Schildkröten unter 20m in Bonaire, kaltes Wasser',
      );
      expect(boundOf(compiled, 'waterTemp', QueryOp.lte), 15);
    });

    test('a sentence that names its period keeps it', () async {
      final c = make(_Engine(embellished));
      await askOf(c).ask('Turtles below 20m in Bonaire since 2022');
      expect(
        stateOf(c).answer!.compiled.chips.map((ch) => ch.ref),
        contains(ChipRef.time),
      );
    });
  });

  // Copilot review: a chip removed while the model worked came back on
  // Undo, which restored the query from when the Ask started.
  test('Undo returns to the query from just before the answer', () async {
    final engine = _Engine()..gates['deep dives'] = Completer<String>();
    final c = make(engine, filter: DiveFilterState(query: TextNode(['reef'])));
    final pending = askOf(c).ask('deep dives');
    await Future<void>.delayed(Duration.zero);
    final notifier = c.read(diveFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(query: TextNode(['wreck']));
    engine.gates['deep dives']!.complete(_deep);
    await pending;
    askOf(c).undo();
    expect(filterOf(c).query, TextNode(['wreck']));
  });

  // Copilot review: the recent sentence was filed under whichever diver
  // was active when the write ran, not when the Ask started.
  test('the asked sentence is remembered for the diver who asked', () async {
    String? filedUnder;
    final engine = _Engine()..gates['deep dives'] = Completer<String>();
    final c = make(
      engine,
      recorder: (sentence, locale, parsed, diverId) async =>
          filedUnder = diverId,
    );
    final pending = askOf(c).ask('deep dives');
    await Future<void>.delayed(Duration.zero);
    c.read(_diver.notifier).state = 'ben';
    engine.gates['deep dives']!.complete(_deep);
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(filedUnder, 'ana');
  });

  test('prepare warms the model once', () async {
    final engine = _Engine(_turtles);
    final c = make(engine);
    askOf(c)
      ..prepare()
      ..prepare();
    await Future<void>.delayed(Duration.zero);
    expect(engine.prepareCalls, 1);
  });
}
