import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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

void main() {
  const turtles =
      '{"schemaVersion":1,"subject":"dives","clauses":[{"field":"depth",'
      '"op":"gt","value":20,"unit":"m","text":"below 20m"}],"mentions":'
      '[{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":["maybe"]}';

  ProviderContainer make(NlEngine engine) => ProviderContainer(
    overrides: [
      nlEngineProvider.overrideWithValue(engine),
      localeProvider.overrideWithValue('en'),
      unitPrefsProvider.overrideWithValue(const (
        depth: DepthUnit.meters,
        temperature: TemperatureUnit.celsius,
        pressure: PressureUnit.bar,
      )),
      nameIndexProvider.overrideWith(
        (ref) async => const NameIndex([
          NameEntry(
            kind: MentionKind.place,
            label: 'Bonaire',
            ids: ['s1', 's2'],
            target: NameTarget.sitePlace,
          ),
        ]),
      ),
      recentQueryRecorderProvider.overrideWithValue(
        (sentence, locale, parsed) async {},
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
    expect(s.compiled!.filter.minDepth, 20);
    expect(s.compiled!.filter.siteIds, ['s1', 's2']);
    expect(s.compiled!.unplaced.single.text, 'maybe');
    expect(c.read(exploreFilterProvider).siteIds, ['s1', 's2']);
    expect(engine.compileCalls, 1);
  });

  test('removeChip recompiles without the model', () async {
    final engine = _ScriptedEngine(turtles);
    final c = make(engine);
    final n = c.read(exploreQueryProvider.notifier);
    await n.run('x');
    n.removeChip(c.read(exploreQueryProvider).compiled!.chips.first);
    expect(c.read(exploreFilterProvider).minDepth, isNull);
    expect(c.read(exploreFilterProvider).siteIds, ['s1', 's2']);
    expect(engine.compileCalls, 1);
  });

  test(
    'invalid JSON is a schema mismatch error and leaves the filter empty',
    () async {
      final c = make(_ScriptedEngine('{"schemaVersion":7}'));
      await c.read(exploreQueryProvider.notifier).run('x');
      expect(c.read(exploreQueryProvider).error, NlError.schemaMismatch);
      expect(c.read(exploreFilterProvider).hasActiveFilters, isFalse);
    },
  );

  test('an engine exception surfaces as its error', () async {
    final c = make(_ThrowingEngine());
    await c.read(exploreQueryProvider.notifier).run('x');
    expect(c.read(exploreQueryProvider).error, NlError.contextExceeded);
  });

  test('a non-object JSON root is a schema mismatch, not a hang', () async {
    // The Android adapter is prompt-only, so the model can return a list.
    // The notifier must land on an error rather than stay running.
    final c = make(_ScriptedEngine('[1, 2]'));
    await c.read(exploreQueryProvider.notifier).run('x');
    final s = c.read(exploreQueryProvider);
    expect(s.error, NlError.schemaMismatch);
    expect(s.running, isFalse);
  });

  test('text that is not JSON at all is a schema mismatch', () async {
    final c = make(_ScriptedEngine('I could not answer that'));
    await c.read(exploreQueryProvider.notifier).run('x');
    expect(c.read(exploreQueryProvider).error, NlError.schemaMismatch);
    expect(c.read(exploreQueryProvider).running, isFalse);
  });

  test('clear resets the state and the published filter', () async {
    final c = make(_ScriptedEngine(turtles));
    final n = c.read(exploreQueryProvider.notifier);
    await n.run('x');
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
        '{"schemaVersion":1,"subject":"dives","mentions":'
        '[{"kind":"place","text":"bonar"}],"unplaced":[]}',
      ),
    );
    final n = c.read(exploreQueryProvider.notifier);
    await n.run('x');
    final unresolved = c.read(exploreQueryProvider).compiled!.unresolved;
    expect(unresolved, hasLength(1));
    n.resolveWith(
      0,
      const NameEntry(
        kind: MentionKind.place,
        label: 'Bonaire',
        ids: ['s1', 's2'],
        target: NameTarget.sitePlace,
      ),
    );
    expect(c.read(exploreFilterProvider).siteIds, ['s1', 's2']);
    expect(c.read(exploreQueryProvider).compiled!.unresolved, isEmpty);
  });

  test('resolveWith on an out-of-range index is ignored', () async {
    final c = make(_ScriptedEngine(turtles));
    final n = c.read(exploreQueryProvider.notifier);
    await n.run('x');
    final before = c.read(exploreFilterProvider);
    n.resolveWith(
      99,
      const NameEntry(
        kind: MentionKind.place,
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

  test('rerun with a stored parse skips the model', () async {
    final engine = _ScriptedEngine(turtles);
    final c = make(engine);
    await c
        .read(exploreQueryProvider.notifier)
        .rerun(
          'x',
          ParsedQuery.fromJson({'schemaVersion': 1, 'subject': 'dives'}),
        );
    expect(engine.compileCalls, 0);
    expect(c.read(exploreQueryProvider).compiled, isNotNull);
  });
}
