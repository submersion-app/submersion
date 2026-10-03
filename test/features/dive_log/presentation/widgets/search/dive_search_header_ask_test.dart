import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_notice.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Answers each sentence from [replies]; [gates] holds an answer back
/// until the test completes it.
class _Engine implements NlEngine {
  final replies = <String, String>{};
  final gates = <String, Completer<String>>{};
  int compileCalls = 0;
  int prepareCalls = 0;
  Object? throwing;

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
    return Future.value(replies[sentence] ?? _nothing);
  }
}

const _deep =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
    '"op":"gte","value":40,"unit":"m","text":"deep"}],"mentions":[],"time":null,"unplaced":[]}';
const _nothing =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[],"mentions":[],'
    '"time":null,"unplaced":["fluffy clouds"]}';
const _goodSites =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
    '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,"unplaced":[]}';

/// Ask in the dive search row (#2773): the row, Cmd/Ctrl+Enter, Undo and
/// handoff, against a fake on-device model.
void main() {
  late ProviderContainer container;

  Future<void> pumpHeader(
    WidgetTester tester, {
    required _Engine engine,
    Future<NameIndex> Function(Ref ref)? names,
    DiveFilterState filter = const DiveFilterState(),
    bool supported = true,
    NlAvailability? availability,
  }) async {
    final base = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return DiveSearchHeader(onOpenDive: (_) {});
              },
            ),
          ),
        ),
        GoRoute(
          path: '/sites',
          builder: (context, _) => const Scaffold(body: Text('Sites page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveFilterProvider.overrideWith((ref) => filter),
          diveSearchBarOpenProvider.overrideWith((ref) => true),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith(
            (ref, q) async => const <DiveSummary>[],
          ),
          nlEngineProvider.overrideWithValue(engine),
          explorePlatformSupportedProvider.overrideWithValue(supported),
          exploreAvailabilityProvider.overrideWith(
            (ref) async =>
                availability ??
                (supported
                    ? NlAvailability.available
                    : NlAvailability.unsupportedPlatform),
          ),
          localeProvider.overrideWithValue('en'),
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
            (ref) => names?.call(ref) ?? Future.value(NameIndex.empty),
          ),
          recentQueryRecorderProvider.overrideWithValue((s, l, p, d) async {}),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Control+Enter in every run: platformShortcut reads Cmd on macOS. The
  // variant sets and restores the platform around each test.
  void testAsk(String description, WidgetTesterCallback body) => testWidgets(
    description,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  DiveFilterState filterOf() => container.read(diveFilterProvider);

  TextField fieldOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));

  testAsk('typed text offers Ask, and asking replaces the query', (
    tester,
  ) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    expect(find.text('Ask: deep dives'), findsOneWidget);
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(filterOf().query, isNotNull);
    expect(fieldOf(tester).controller!.text, contains('40'));
    expect(find.text('Asked: deep dives'), findsOneWidget);
  });

  testAsk('Cmd/Ctrl+Enter asks', (tester) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Asked: deep dives'), findsOneWidget);
  });

  // Review Focus 2.
  testAsk('words still waiting on the debounce never land on the answer', (
    tester,
  ) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    final answered = filterOf().query;
    expect(answered, isNotNull);
    expect(answered, container.read(diveAskProvider).answer!.compiled.query);
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, answered);
  });

  // Review: an answer equal to the query already applied changes nothing
  // the filter listener sees, so the typed words still waited to land.
  testAsk('re-asking within the debounce keeps the same answer', (
    tester,
  ) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    final answered = filterOf().query;
    expect(answered, isNotNull);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, answered);
    // Copilot review: the field kept the typed sentence while the answer
    // (equal to the applied query) filtered the list.
    expect(fieldOf(tester).controller!.text, isNot('deep dives'));
    expect(fieldOf(tester).controller!.text, contains('40'));
  });

  // Code review: the Explore page kept the name index listened while it
  // was open; without a listener the legacy buddy names pause, and a dive
  // write only marks them due, so the next Ask read stale names.
  testAsk('the search row keeps the names Ask resolves against live', (
    tester,
  ) async {
    var builds = 0;
    var listened = false;
    await pumpHeader(
      tester,
      engine: _Engine(),
      names: (ref) async {
        builds++;
        listened = true;
        // A rebuild re-registers the row's listener, so the count may touch
        // zero in between; what matters is that it is listened at rest.
        ref.onCancel(() => listened = false);
        ref.onResume(() => listened = true);
        return NameIndex.empty;
      },
    );
    expect(builds, 1);
    expect(listened, isTrue);
  });

  // Code review: editing the printed answer moves away from it, so Undo
  // must not then throw the unfinished edit away.
  testAsk('editing after an answer drops the notice', (tester) async {
    await pumpHeader(tester, engine: _Engine()..replies['deep dives'] = _deep);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveAskNoticeKey), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'depth >');
    await tester.pump();
    expect(find.byKey(kDiveAskNoticeKey), findsNothing);
  });

  // Code review: an error kept after the field was re-printed showed an
  // empty "Ask: " row that did nothing.
  testAsk('a re-printed field hides the Ask row and its old error', (
    tester,
  ) async {
    final engine = _Engine()
      ..throwing = const NlException(NlError.quotaExceeded);
    await pumpHeader(tester, engine: engine);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(
      find.text('The on-device model is busy. Try again in a moment.'),
      findsOneWidget,
    );
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: TextNode(['wreck']),
    );
    await tester.pump();
    expect(find.byKey(kDiveAskRowKey), findsNothing);
  });

  // Code review: focusing search to type a word warmed the language model.
  testAsk('the model warms up on the first typed text, not on focus', (
    tester,
  ) async {
    final engine = _Engine();
    await pumpHeader(tester, engine: engine);
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    expect(engine.prepareCalls, 0);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'turtles');
    await tester.pump();
    expect(engine.prepareCalls, 1);
  });

  // Code review: on a supported platform without a usable model, the
  // one warm-up was spent on no model, and the names reloaded for nothing.
  testAsk('no warm-up and no live names until the model is available', (
    tester,
  ) async {
    final engine = _Engine();
    var builds = 0;
    await pumpHeader(
      tester,
      engine: engine,
      availability: NlAvailability.downloadable,
      names: (ref) async {
        builds++;
        return NameIndex.empty;
      },
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'turtles');
    await tester.pump();
    expect(engine.prepareCalls, 0);
    expect(builds, 0);
  });

  // Review Focus 1.
  testAsk('typing while the model works cancels the Ask', (tester) async {
    final engine = _Engine()..gates['deep dives'] = Completer<String>();
    await pumpHeader(tester, engine: engine);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    expect(find.text('Asking the on-device model'), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    engine.gates['deep dives']!.complete(_deep);
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, TextNode(['manta']));
    expect(find.text('Asking the on-device model'), findsNothing);
  });

  // Review Focus 5.
  // A sentence that does not parse writes nothing before the Ask, so Undo
  // goes back to the query from before it.
  testAsk('Undo puts the sentence back and the old query', (tester) async {
    await pumpHeader(
      tester,
      engine: _Engine()..replies['deep dives, please'] = _deep,
      filter: DiveFilterState(query: TextNode(['reef'])),
    );
    await tester.enterText(
      find.byKey(kDiveSearchFieldKey),
      'deep dives, please',
    );
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kDiveAskUndoKey));
    await tester.pump();
    expect(fieldOf(tester).controller!.text, 'deep dives, please');
    expect(filterOf().query, TextNode(['reef']));
    // Shown, not applied: still the old query once any debounce is over.
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, TextNode(['reef']));
  });

  // A sentence that parses applies as typed text before the Ask, so Undo
  // returns to its words: the field and the list agree.
  testAsk('Undo after a parsed sentence returns to its words', (tester) async {
    await pumpHeader(
      tester,
      engine: _Engine()..replies['deep dives'] = _deep,
      filter: DiveFilterState(query: TextNode(['reef'])),
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kDiveAskUndoKey));
    await tester.pump(kDiveSearchDebounce * 2);
    expect(fieldOf(tester).controller!.text, 'deep dives');
    expect(
      filterOf().query,
      AndNode([
        TextNode(['deep']),
        TextNode(['dives']),
      ]),
    );
  });

  testAsk('a sentence about sites opens the site list', (tester) async {
    await pumpHeader(
      tester,
      engine: _Engine()..replies['sites rated 4'] = _goodSites,
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'sites rated 4');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(find.text('Sites page'), findsOneWidget);
  });

  testAsk('Open in list takes a waiting answer to its list', (tester) async {
    const cosySites =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
        '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,'
        '"unplaced":["cosy"]}';
    await pumpHeader(
      tester,
      engine: _Engine()..replies['cosy sites rated 4'] = cosySites,
    );
    await tester.enterText(
      find.byKey(kDiveSearchFieldKey),
      'cosy sites rated 4',
    );
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(find.text('Sites page'), findsNothing);
    await tester.tap(find.byKey(kDiveAskOpenListKey));
    await tester.pumpAndSettle();
    expect(find.text('Sites page'), findsOneWidget);
  });

  // Code review: an answer that replaces nothing must not strand the typed
  // words: the field shows them, so they apply as typed text does.
  testAsk('an answer kept in the notice lets the typed words apply', (
    tester,
  ) async {
    const cosySites =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
        '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,'
        '"unplaced":["cosy"]}';
    await pumpHeader(
      tester,
      engine: _Engine()..replies['cosy sites rated 4'] = cosySites,
    );
    await tester.enterText(
      find.byKey(kDiveSearchFieldKey),
      'cosy sites rated 4',
    );
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    await tester.pump(kDiveSearchDebounce * 2);
    expect(find.byKey(kDiveAskNoticeKey), findsOneWidget);
    expect(filterOf().query, isNotNull);
  });

  // Code review: a model faster than the debounce answered nothing, then
  // the typed words landed and took the notice away with them.
  testAsk('a fast empty answer keeps its notice when the words land', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      engine: _Engine()..replies['fluffy clouds'] = _nothing,
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'fluffy clouds');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    await tester.pump(kDiveSearchDebounce * 2);
    expect(find.byKey(kDiveAskNoticeKey), findsOneWidget);
  });

  testAsk('no Ask row and no Cmd/Ctrl+Enter where the model is off', (
    tester,
  ) async {
    final engine = _Engine()..replies['deep dives'] = _deep;
    await pumpHeader(tester, engine: engine, supported: false);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'deep dives');
    await tester.pump();
    expect(find.byKey(kDiveAskRowKey), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(engine.compileCalls, 0);
  });

  testAsk('closing the row drops the notice', (tester) async {
    await pumpHeader(tester, engine: _Engine()..replies['x'] = _nothing);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'x');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveAskNoticeKey), findsOneWidget);
    await tester.tap(find.byKey(kDiveSearchCloseKey));
    await tester.pumpAndSettle();
    expect(container.read(diveAskProvider).answer, isNull);
  });
}
