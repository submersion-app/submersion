import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../domain/explore_query_parts.dart';

class _ScriptedEngine implements NlEngine {
  _ScriptedEngine(this.json);
  final String json;
  int compileCalls = 0;

  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) async {
    compileCalls++;
    return json;
  }
}

class _ThrowingEngine implements NlEngine {
  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) async =>
      throw const NlException(NlError.contextExceeded);
}

Future<NameIndex> _bonaireLoader() async => NameIndex(const [
  NameEntry(
    subject: QuerySubject.sites,
    label: 'Bonaire',
    ids: ['s1', 's2'],
    target: NameTarget.sitePlace,
  ),
]);

/// An engine whose answer arrives only when the test says so, to order a
/// slow model call against a later request.
class _GatedEngine implements NlEngine {
  final gates = <String, Completer<String>>{};

  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) =>
      (gates[sentence] = Completer<String>()).future;
}

void main() {
  const turtles =
      '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
      '"op":"gt","value":20,"unit":"m","text":"below 20m"}],"mentions":'
      '[{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":["maybe"]}';
  // Grounding drops a clause whose words the sentence lacks (#2838), so a
  // canned reply needs a sentence that says it.
  const turtlesSentence = 'Turtles below 20m in Bonaire maybe';

  // Parameterized rather than re-overridden per test: a second override of
  // the same provider later in the list does not win.
  ProviderContainer make(
    NlEngine engine, {
    Future<NameIndex> Function() names = _bonaireLoader,
    RecentQueryRecorder? recorder,
    String locale = 'en',
    Locale device = const Locale('en', 'US'),
  }) => ProviderContainer(
    overrides: [
      nlEngineProvider.overrideWithValue(engine),
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
      exploreNameIndexProvider.overrideWith((ref) => names()),
      recentQueryRecorderProvider.overrideWithValue(
        recorder ?? (sentence, locale, parsed) async {},
      ),
    ],
  );

  test('run compiles the sentence and publishes the filter', () async {
    final engine = _ScriptedEngine(turtles);
    final c = make(engine);
    await c
        .read(exploreQueryProvider.notifier)
        .run('Turtles below 20m in Bonaire');
    final s = c.read(exploreQueryProvider);
    expect(s.running, isFalse);
    expect(s.error, isNull);
    expect(boundOf(s.compiled!, 'depth', QueryOp.gte), 20);
    expect(refIdsOf(s.compiled!, ['site']), ['s1', 's2']);
    expect(s.compiled!.unplaced.single.text, 'maybe');
    expect(c.read(exploreFilterProvider).query, s.compiled!.query);
    expect(engine.compileCalls, 1);
  });

  test('removeChip recompiles without the model', () async {
    final engine = _ScriptedEngine(turtles);
    final c = make(engine);
    final n = c.read(exploreQueryProvider.notifier);
    await n.run(turtlesSentence);
    n.removeChip(c.read(exploreQueryProvider).compiled!.chips.first);
    expect(
      boundIn(c.read(exploreFilterProvider).query, 'depth', QueryOp.gte),
      isNull,
    );
    expect(refIdsIn(c.read(exploreFilterProvider).query, ['site']), [
      's1',
      's2',
    ]);
    expect(engine.compileCalls, 1);
  });

  test(
    'invalid JSON is a schema mismatch error and leaves the filter empty',
    () async {
      final c = make(_ScriptedEngine('{"schemaVersion":7}'));
      await c.read(exploreQueryProvider.notifier).run(turtlesSentence);
      expect(c.read(exploreQueryProvider).error, NlError.schemaMismatch);
      expect(c.read(exploreFilterProvider).hasActiveFilters, isFalse);
    },
  );

  test('an engine exception surfaces as its error', () async {
    final c = make(_ThrowingEngine());
    await c.read(exploreQueryProvider.notifier).run(turtlesSentence);
    expect(c.read(exploreQueryProvider).error, NlError.contextExceeded);
  });

  test('a non-object JSON root is a schema mismatch, not a hang', () async {
    // The Android adapter is prompt-only, so the model can return a list.
    // The notifier must land on an error rather than stay running.
    final c = make(_ScriptedEngine('[1, 2]'));
    await c.read(exploreQueryProvider.notifier).run(turtlesSentence);
    final s = c.read(exploreQueryProvider);
    expect(s.error, NlError.schemaMismatch);
    expect(s.running, isFalse);
  });

  test('text that is not JSON at all is a schema mismatch', () async {
    final c = make(_ScriptedEngine('I could not answer that'));
    await c.read(exploreQueryProvider.notifier).run(turtlesSentence);
    expect(c.read(exploreQueryProvider).error, NlError.schemaMismatch);
    expect(c.read(exploreQueryProvider).running, isFalse);
  });

  test('clear resets the state and the published filter', () async {
    final c = make(_ScriptedEngine(turtles));
    final n = c.read(exploreQueryProvider.notifier);
    await n.run(turtlesSentence);
    expect(c.read(exploreFilterProvider).hasActiveFilters, isTrue);
    n.clear();
    expect(c.read(exploreQueryProvider).compiled, isNull);
    expect(c.read(exploreQueryProvider).sentence, isEmpty);
    expect(c.read(exploreFilterProvider).hasActiveFilters, isFalse);
  });

  test('an empty sentence never reaches the model', () async {
    final engine = _ScriptedEngine(turtles);
    final c = make(engine);
    await c.read(exploreQueryProvider.notifier).run('   ');
    expect(engine.compileCalls, 0);
    expect(c.read(exploreQueryProvider).compiled, isNull);
  });

  test('resolveWith swaps the mention and recompiles', () async {
    final c = make(
      _ScriptedEngine(
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","mentions":'
        '[{"kind":"place","text":"bonar"}],"unplaced":[]}',
      ),
    );
    final n = c.read(exploreQueryProvider.notifier);
    await n.run(turtlesSentence);
    final unresolved = c.read(exploreQueryProvider).compiled!.unresolved;
    expect(unresolved, hasLength(1));
    n.resolveWith(
      0,
      const NameEntry(
        subject: QuerySubject.sites,
        label: 'Bonaire',
        ids: ['s1', 's2'],
        target: NameTarget.sitePlace,
      ),
    );
    expect(refIdsIn(c.read(exploreFilterProvider).query, ['site']), [
      's1',
      's2',
    ]);
    expect(c.read(exploreQueryProvider).compiled!.unresolved, isEmpty);
  });

  test('resolveWith on an out-of-range index is ignored', () async {
    final c = make(_ScriptedEngine(turtles));
    final n = c.read(exploreQueryProvider.notifier);
    await n.run(turtlesSentence);
    final before = c.read(exploreFilterProvider);
    n.resolveWith(
      99,
      const NameEntry(
        subject: QuerySubject.sites,
        label: 'Bonaire',
        ids: ['s1'],
        target: NameTarget.sitePlace,
      ),
    );
    expect(c.read(exploreFilterProvider), before);
  });

  test('removeChip before any query is a no-op', () {
    final c = make(_ScriptedEngine(turtles));
    c
        .read(exploreQueryProvider.notifier)
        .removeChip(
          const QueryChip(ref: ChipRef.time, index: 0, payload: TimeChip()),
        );
    expect(c.read(exploreQueryProvider).compiled, isNull);
  });

  group('grounding (#2838)', () {
    // What the model returned for "Turtles below 20m in Bonaire" with the
    // old prompt: a filter and a period copied from the prompt's examples.
    const embellished =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":['
        '{"field":"depth","op":"gt","value":20,"unit":"m","text":"below 20m"},'
        '{"field":"waterTemp","op":"lt","value":15,"unit":"c",'
        '"text":"cold-water"}],"mentions":[{"kind":"place","text":"Bonaire"}],'
        '"time":"since 2022","unplaced":[]}';

    test('a filter or year the sentence never said is not applied', () async {
      ParsedQuery? recorded;
      final c = make(
        _ScriptedEngine(embellished),
        recorder: (sentence, locale, parsed) async => recorded = parsed,
      );
      await c
          .read(exploreQueryProvider.notifier)
          .run('Turtles below 20m in Bonaire');
      final s = c.read(exploreQueryProvider);
      expect(boundOf(s.compiled!, 'depth', QueryOp.gte), 20);
      expect(boundOf(s.compiled!, 'waterTemp', QueryOp.lte), isNull);
      expect(
        s.compiled!.chips.map((ch) => ch.ref),
        isNot(contains(ChipRef.time)),
      );
      expect(s.compiled!.unplaced, isEmpty);
      // The recent list replays what the diver saw, not the raw reply.
      expect(recorded!.clauses.map((cl) => cl.text), ['below 20m']);
      expect(recorded!.time, isNull);
    });

    // 'system' is the default locale setting: the device's language decides
    // whether the clause words are checked.
    Future<ExploreCompilation> askOnDevice(Locale device, String sentence) {
      final c = make(
        _ScriptedEngine(embellished),
        locale: 'system',
        device: device,
      );
      return c
          .read(exploreQueryProvider.notifier)
          .run(sentence)
          .then((_) => c.read(exploreQueryProvider).compiled!);
    }

    test('following an English device, invented clauses are dropped', () async {
      final compiled = await askOnDevice(
        const Locale('en', 'US'),
        'Turtles below 20m in Bonaire',
      );
      expect(boundOf(compiled, 'waterTemp', QueryOp.lte), isNull);
    });

    test('following a German device, clauses are kept', () async {
      // The model may quote a German clause in English, so nothing is
      // checked; "cold-water" stands in for such a quote here.
      final compiled = await askOnDevice(
        const Locale('de', 'DE'),
        'Schildkröten unter 20m in Bonaire, kaltes Wasser',
      );
      expect(boundOf(compiled, 'waterTemp', QueryOp.lte), 15);
    });

    test('a sentence that names its period keeps it', () async {
      final c = make(_ScriptedEngine(embellished));
      await c
          .read(exploreQueryProvider.notifier)
          .run('Turtles below 20m in Bonaire since 2022');
      final chips = c.read(exploreQueryProvider).compiled!.chips;
      expect(chips.map((ch) => ch.ref), contains(ChipRef.time));
    });
  });

  group('replay', () {
    RecentQuery recent(ParsedQuery? parsed) => RecentQuery(
      sentence: turtlesSentence,
      locale: 'en',
      parsed: parsed,
      lastUsedAt: DateTime(2026, 9, 1),
    );

    test('a recent with a current parse skips the model', () async {
      final engine = _ScriptedEngine(turtles);
      final c = make(engine);
      await c
          .read(exploreQueryProvider.notifier)
          .replay(recent(ParsedQuery.fromDecoded(jsonDecode(turtles))));
      expect(engine.compileCalls, 0);
      expect(c.read(exploreQueryProvider).compiled, isNotNull);
    });

    test('a recent from an older prompt asks the model again', () async {
      final engine = _ScriptedEngine(turtles);
      final c = make(engine);
      await c.read(exploreQueryProvider.notifier).replay(recent(null));
      expect(engine.compileCalls, 1);
      final s = c.read(exploreQueryProvider);
      expect(s.sentence, turtlesSentence);
      expect(boundOf(s.compiled!, 'depth', QueryOp.gte), 20);
    });
  });

  test('rerun with a stored parse skips the model', () async {
    final engine = _ScriptedEngine(turtles);
    final c = make(engine);
    await c
        .read(exploreQueryProvider.notifier)
        .rerun(
          'x',
          ParsedQuery.fromJson({
            'schemaVersion': kQuerySchemaVersion,
            'subject': 'dives',
          }),
        );
    expect(engine.compileCalls, 0);
    expect(c.read(exploreQueryProvider).compiled, isNotNull);
  });

  group('review fixes', () {
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

    test('choosing between two same-named buddies sticks', () async {
      final c = make(_ScriptedEngine(withJohn), names: () async => twins);
      final n = c.read(exploreQueryProvider.notifier);
      await n.run('dives with John Smith');
      expect(c.read(exploreQueryProvider).compiled!.unresolved, hasLength(1));
      n.resolveWith(0, twins.entries[1]);
      expect(
        (conditionsIn(c.read(exploreFilterProvider).query, [
                  'buddies',
                ], QueryOp.eq).single.value!
                as RefValue)
            .id,
        'john-b',
      );
      expect(c.read(exploreQueryProvider).compiled!.unresolved, isEmpty);
    });

    test('an unexpected failure ends the run with an error', () async {
      final c = make(
        _ScriptedEngine(turtles),
        names: () async => throw StateError('index build failed'),
      );
      await c.read(exploreQueryProvider.notifier).run(turtlesSentence);
      final s = c.read(exploreQueryProvider);
      expect(s.running, isFalse);
      expect(s.error, NlError.unknown);
    });

    test('a failed recent-query write does not hide a good answer', () async {
      final c = make(
        _ScriptedEngine(turtles),
        recorder: (sentence, locale, parsed) async =>
            throw StateError('cache full'),
      );
      await c.read(exploreQueryProvider.notifier).run(turtlesSentence);
      final s = c.read(exploreQueryProvider);
      expect(s.running, isFalse);
      expect(s.error, isNull);
      expect(boundOf(s.compiled!, 'depth', QueryOp.gte), 20);
    });

    test('a slow reply cannot overwrite a newer request', () async {
      final engine = _GatedEngine();
      final c = make(engine);
      final n = c.read(exploreQueryProvider.notifier);
      final first = n.run('first');
      await Future<void>.delayed(Duration.zero);
      // A recent chip re-runs a stored parse while the model is still busy.
      await n.rerun(
        'second',
        ParsedQuery.fromJson(const {
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': [
            {'field': 'depth', 'op': 'gte', 'value': 40, 'text': 'deep'},
          ],
        }),
      );
      engine.gates['first']!.complete(turtles);
      await first;
      final s = c.read(exploreQueryProvider);
      expect(s.sentence, 'second');
      expect(boundOf(s.compiled!, 'depth', QueryOp.gte), 40);
      expect(c.read(exploreFilterProvider).query, s.compiled!.query);
    });
  });
}
