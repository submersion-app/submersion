import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
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
