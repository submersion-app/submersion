import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_history_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_history_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

BuoyancyHistoryEntry _entry(int day, double carried, double ideal) =>
    BuoyancyHistoryEntry(
      diveId: 'h$day',
      diveDateTime: DateTime(2026, 5, day),
      carriedKg: carried,
      idealKg: ideal,
    );

final _history = [_entry(1, 6, 5), _entry(2, 7, 5)];

const _current = BuoyancyHistoryCurrent(carriedKg: 6, idealKg: 7.8);

Future<void> _pump(
  WidgetTester tester, {
  List<BuoyancyHistoryEntry>? history,
  BuoyancyHistoryCurrent? current = _current,
  double width = 400,
  AppSettings settings = const AppSettings(),
}) async {
  await tester.binding.setSurfaceSize(Size(width, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        buoyancyHistoryProvider(
          'd1',
        ).overrideWith((ref) async => history ?? _history),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuoyancyHistoryStrip(
            diveId: 'd1',
            units: UnitFormatter(settings),
            current: current,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _readout() => find.byKey(const ValueKey('history-readout'));

String _readoutText(WidgetTester tester) =>
    tester.widget<Text>(_readout()).data!;

Finder _bar(String series, int index) =>
    find.byKey(ValueKey('history-$series-$index'));

void main() {
  // The dates come from Intl.defaultLocale, a process global the app sets
  // from its locale; MaterialApp.locale does not touch it. Pin it so the
  // expected 'May 1' holds whatever locale the test process starts in.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('the caption says what is compared, over how many dives', (
    tester,
  ) async {
    await _pump(tester);
    // Two past dives in this suit, and this one.
    expect(find.text('Lead on your last 3 dives in this suit'), findsOneWidget);
  });

  testWidgets('without lead on this dive only the past dives count', (
    tester,
  ) async {
    await _pump(tester, current: null);
    expect(find.text('Lead on your last 2 dives in this suit'), findsOneWidget);
    expect(find.text('This dive'), findsNothing);
  });

  testWidgets('each pair is dated, and this dive is named', (tester) async {
    await _pump(tester);
    expect(find.text('May 1'), findsOneWidget);
    expect(find.text('May 2'), findsOneWidget);
    expect(find.text('This dive'), findsOneWidget);
  });

  testWidgets('the legend names what the model suggests', (tester) async {
    await _pump(tester);
    expect(find.text('Carried'), findsOneWidget);
    expect(find.text('Model suggests'), findsOneWidget);
    expect(find.text('Modeled'), findsNothing);
  });

  testWidgets('the readout starts on this dive', (tester) async {
    await _pump(tester);
    expect(
      _readoutText(tester),
      'This dive: Carried 6.0 kg, Model suggests 7.8 kg',
    );
  });

  testWidgets('without this dive the readout starts on the latest dive', (
    tester,
  ) async {
    await _pump(tester, current: null);
    expect(
      _readoutText(tester),
      'May 2: Carried 7.0 kg, Model suggests 5.0 kg',
    );
  });

  testWidgets('tapping a pair shows its values', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('history-dive-0')));
    await tester.pump();
    expect(
      _readoutText(tester),
      'May 1: Carried 6.0 kg, Model suggests 5.0 kg',
    );
  });

  testWidgets('a screen reader hears each pair as a button with its values', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('history-dive-0'))),
      matchesSemantics(
        label: 'May 1: Carried 6.0 kg, Model suggests 5.0 kg',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the weight axis is marked in round steps', (tester) async {
    // The tallest value is 7.8 kg, so the axis runs to 10 kg.
    await _pump(tester);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('5 kg'), findsOneWidget);
    expect(find.text('10 kg'), findsOneWidget);
  });

  testWidgets('bars are drawn to the axis', (tester) async {
    await _pump(tester);
    final carried = tester.getSize(_bar('carried', 0)).height;
    final suggested = tester.getSize(_bar('suggested', 0)).height;
    final top = tester.getRect(find.text('10 kg')).center.dy;
    final zero = tester.getRect(find.text('0')).center.dy;
    // 6 and 5 kg against a 10 kg axis.
    expect(carried, closeTo((zero - top) * 0.6, 0.5));
    expect(suggested, closeTo((zero - top) * 0.5, 0.5));
  });

  testWidgets('an imperial diver reads lb on the axis and the readout', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const AppSettings(weightUnit: WeightUnit.pounds),
    );
    expect(find.text('10 lbs'), findsOneWidget);
    expect(find.text('20 lbs'), findsOneWidget);
    expect(
      _readoutText(tester),
      'This dive: Carried 13.2 lbs, Model suggests 17.2 lbs',
    );
  });

  testWidgets('a long history on a narrow card thins its dates, never '
      'overlapping', (tester) async {
    await _pump(
      tester,
      history: [for (var d = 1; d <= 10; d++) _entry(d, 6, 5)],
      width: 300,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('This dive'), findsOneWidget);
    final labels = [
      for (final e in tester.widgetList(
        find.descendant(
          of: find.byKey(const ValueKey('history-dates')),
          matching: find.byType(Text),
        ),
      ))
        tester.getRect(find.byWidget(e)),
    ]..sort((a, b) => a.left.compareTo(b.left));
    expect(labels.length, lessThan(11));
    for (var i = 1; i < labels.length; i++) {
      expect(labels[i].left, greaterThanOrEqualTo(labels[i - 1].right));
    }
  });

  testWidgets('many dives on a very narrow card still fit their slots', (
    tester,
  ) async {
    // Eleven pairs in about 90 px of plot leave each slot under the 8 px two
    // full-width bars and their gap would need.
    await _pump(
      tester,
      history: [for (var d = 1; d <= 10; d++) _entry(d, 6, 5)],
      width: 130,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the axis and dates are left to the pairs for a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('10 kg'), findsNothing);
    expect(find.bySemanticsLabel('May 1'), findsNothing);
    handle.dispose();
  });

  testWidgets('a picked dive stays picked when the history refreshes around '
      'it', (tester) async {
    var history = _history;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buoyancyHistoryProvider('d1').overrideWith((ref) async => history),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BuoyancyHistoryStrip(
              diveId: 'd1',
              units: UnitFormatter(AppSettings()),
              current: _current,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Pick May 2, the second pair.
    await tester.tap(find.byKey(const ValueKey('history-dive-1')));
    await tester.pump();
    expect(_readoutText(tester), startsWith('May 2'));

    // An older dive joins the front of the list, moving May 2 along a place.
    history = [_entry(30, 9, 5), ..._history];
    ProviderScope.containerOf(
      tester.element(find.byType(BuoyancyHistoryStrip)),
    ).invalidate(buoyancyHistoryProvider('d1'));
    await tester.pumpAndSettle();
    expect(_readoutText(tester), startsWith('May 2'));

    // And once it leaves the list, the readout falls back to this dive.
    history = [_entry(1, 6, 5)];
    ProviderScope.containerOf(
      tester.element(find.byType(BuoyancyHistoryStrip)),
    ).invalidate(buoyancyHistoryProvider('d1'));
    await tester.pumpAndSettle();
    expect(_readoutText(tester), startsWith('This dive'));
  });

  testWidgets('a pair tapped on one dive is not kept for the next', (
    tester,
  ) async {
    Widget strip(String diveId) => ProviderScope(
      overrides: [
        buoyancyHistoryProvider('d1').overrideWith((ref) async => _history),
        buoyancyHistoryProvider('d2').overrideWith((ref) async => _history),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuoyancyHistoryStrip(
            diveId: diveId,
            units: const UnitFormatter(AppSettings()),
            current: _current,
          ),
        ),
      ),
    );
    await tester.pumpWidget(strip('d1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-dive-0')));
    await tester.pump();
    expect(_readoutText(tester), startsWith('May 1'));

    await tester.pumpWidget(strip('d2'));
    await tester.pumpAndSettle();
    expect(_readoutText(tester), startsWith('This dive'));
  });

  testWidgets('no past dives in this suit, no chart', (tester) async {
    await _pump(tester, history: const []);
    expect(_readout(), findsNothing);
    expect(find.text('Carried'), findsNothing);
  });
}
