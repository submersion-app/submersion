import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_notice.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';

class _Engine implements NlEngine {
  _Engine(this.json);
  final String json;

  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) async =>
      json;
}

const _turtles =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
    '"op":"gt","value":20,"unit":"m","text":"below 20m"}],"mentions":'
    '[{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":["maybe"]}';
const _deep =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
    '"op":"gte","value":40,"unit":"m","text":"deep"}],"mentions":[],"time":null,"unplaced":[]}';
const _sitesWithLeftovers =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
    '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,"unplaced":["cosy"]}';
const withJohn =
    '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","mentions":'
    '[{"kind":"buddy","text":"John Smith"}],"unplaced":[]}';

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

final _bonaire = NameIndex(const [
  NameEntry(
    subject: QuerySubject.sites,
    label: 'Bonaire',
    ids: ['s1', 's2'],
    target: NameTarget.sitePlace,
  ),
]);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _Engine engine, {
    NameIndex? names,
    VoidCallback? onUndo,
    ValueChanged<String>? onOpenList,
    Locale locale = const Locale('en'),
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: locale,
        overrides: [
          nlEngineProvider.overrideWithValue(engine),
          explorePlatformSupportedProvider.overrideWithValue(true),
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
            (ref) async => names ?? _bonaire,
          ),
          recentQueryRecorderProvider.overrideWithValue(
            (sentence, locale, parsed, diverId) async {},
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return DiveAskNotice(
              onUndo: onUndo ?? () {},
              onOpenList: onOpenList ?? (_) {},
            );
          },
        ),
      ),
    );
    return container;
  }

  testWidgets('lists the unplaced words, each with its reason', (tester) async {
    final c = await pump(tester, _Engine(_turtles));
    await c.read(diveAskProvider.notifier).ask('x');
    await tester.pump();
    expect(find.text("Couldn't use:"), findsOneWidget);
    expect(find.text('maybe'), findsOneWidget);
    // The model's own leftovers carry no reason: no empty tooltip.
    expect(
      find.ancestor(of: find.text('maybe'), matching: find.byType(Tooltip)),
      findsNothing,
    );
  });

  // Review: nothing placed reads as unused, never as "Asked:".
  testWidgets('an answer that placed nothing shows the sentence as unused', (
    tester,
  ) async {
    const empty =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[],'
        '"mentions":[],"time":null,"unplaced":[]}';
    final c = await pump(tester, _Engine(empty));
    await c.read(diveAskProvider.notifier).ask('show me my best dives');
    await tester.pump();
    expect(find.text("Couldn't use:"), findsOneWidget);
    expect(find.widgetWithText(Chip, 'show me my best dives'), findsOneWidget);
    expect(find.textContaining('Asked:'), findsNothing);
  });

  testWidgets('says what was asked when everything was placed', (tester) async {
    final c = await pump(tester, _Engine(_deep));
    await c.read(diveAskProvider.notifier).ask('deep dives');
    await tester.pump();
    expect(find.text('Asked: deep dives'), findsOneWidget);
  });

  testWidgets('a name chip opens the picker and the pick applies', (
    tester,
  ) async {
    final c = await pump(tester, _Engine(withJohn), names: twins);
    await c.read(diveAskProvider.notifier).ask('dives with John Smith');
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, 'John Smith'));
    await tester.pumpAndSettle();
    expect(find.text('Which did you mean by "John Smith"?'), findsOneWidget);
    await tester.tap(find.text('John Smith').last);
    await tester.pumpAndSettle();
    expect(c.read(diveAskProvider).answer!.compiled.unresolved, isEmpty);
  });

  testWidgets('a name with no match says so in the picker', (tester) async {
    const atlantis =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","mentions":'
        '[{"kind":"site","text":"Atlantis"}],"unplaced":[]}';
    final c = await pump(tester, _Engine(atlantis), names: NameIndex.empty);
    await c.read(diveAskProvider.notifier).ask('dives at Atlantis');
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, 'Atlantis'));
    await tester.pumpAndSettle();
    expect(find.text('No match in your logbook'), findsOneWidget);
  });

  // Code review: the buttons shared one row with the text, and long
  // localized labels pushed it past a phone's width.
  testWidgets('fits a 360 px phone with long localized buttons', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    const leftovers =
        '{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"rating",'
        '"op":"gte","value":4,"text":"rated 4"}],"mentions":[],"time":null,'
        '"unplaced":["kuschelig"]}';
    final c = await pump(
      tester,
      _Engine(leftovers),
      locale: const Locale('hu'),
    );
    await c.read(diveAskProvider.notifier).ask('kuschelig sites rated 4');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(kDiveAskOpenListKey), findsOneWidget);
  });

  // Code review: the picker used the notice's ref after the sheet closed,
  // and the notice may be gone by then.
  testWidgets('a pick after the notice went away does nothing', (tester) async {
    final c = await pump(tester, _Engine(withJohn), names: twins);
    await c.read(diveAskProvider.notifier).ask('dives with John Smith');
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, 'John Smith'));
    await tester.pumpAndSettle();
    c.read(diveAskProvider.notifier).dismiss();
    await tester.pump();
    await tester.tap(find.text('John Smith').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(c.read(diveAskProvider).answer, isNull);
  });

  testWidgets('Undo and dismiss', (tester) async {
    var undone = 0;
    final c = await pump(tester, _Engine(_turtles), onUndo: () => undone++);
    await c.read(diveAskProvider.notifier).ask('x');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskUndoKey));
    expect(undone, 1);
    await tester.tap(find.byKey(kDiveAskDismissKey));
    await tester.pump();
    expect(find.byKey(kDiveAskNoticeKey), findsNothing);
  });

  testWidgets('a non-dive answer offers Open in list', (tester) async {
    String? opened;
    final c = await pump(
      tester,
      _Engine(_sitesWithLeftovers),
      onOpenList: (route) => opened = route,
    );
    await c.read(diveAskProvider.notifier).ask('cosy sites rated 4');
    await tester.pump();
    await tester.tap(find.byKey(kDiveAskOpenListKey));
    expect(opened, '/sites');
  });

  testWidgets('a dive answer has no Open in list', (tester) async {
    final c = await pump(tester, _Engine(_turtles));
    await c.read(diveAskProvider.notifier).ask('x');
    await tester.pump();
    expect(find.byKey(kDiveAskOpenListKey), findsNothing);
  });
}
