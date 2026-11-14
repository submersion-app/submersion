import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_balance_bar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

TwinBalance _balance({double suit = 3.0, double tanks = -2.0}) {
  final parts = [
    const TwinBalancePart(kind: TwinBalancePartKind.lead, kg: -6.0),
    TwinBalancePart(kind: TwinBalancePartKind.tanks, kg: tanks),
    const TwinBalancePart(kind: TwinBalancePartKind.gear, kg: -1.0),
    TwinBalancePart(kind: TwinBalancePartKind.suit, kg: suit),
    const TwinBalancePart(kind: TwinBalancePartKind.body, kg: 5.0),
  ];
  return TwinBalance(parts: parts, netKg: parts.fold(0.0, (s, p) => s + p.kg));
}

Future<void> _pump(
  WidgetTester tester,
  TwinBalance balance, {
  double scaleKg = 12.0,
  double width = 800,
  Locale locale = const Locale('en'),
  AppSettings settings = const AppSettings(),
}) async {
  await tester.binding.setSurfaceSize(Size(width, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BuoyancyBalanceBar(
          balance: balance,
          scaleKg: scaleKg,
          units: UnitFormatter(settings),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _segment(TwinBalancePartKind kind) =>
    find.byKey(ValueKey('balance-${kind.name}'));

double _barCentre(WidgetTester tester) =>
    tester.getCenter(find.byType(BuoyancyBalanceBar)).dx;

void main() {
  testWidgets('down parts sit on the start side, up parts on the end side', (
    tester,
  ) async {
    await _pump(tester, _balance());
    final centre = _barCentre(tester);
    for (final kind in [
      TwinBalancePartKind.lead,
      TwinBalancePartKind.tanks,
      TwinBalancePartKind.gear,
    ]) {
      expect(tester.getCenter(_segment(kind)).dx, lessThan(centre));
    }
    for (final kind in [TwinBalancePartKind.suit, TwinBalancePartKind.body]) {
      expect(tester.getCenter(_segment(kind)).dx, greaterThan(centre));
    }
  });

  testWidgets('a tank that floats moves to the up side', (tester) async {
    await _pump(tester, _balance(tanks: 0.6));
    expect(
      tester.getCenter(_segment(TwinBalancePartKind.tanks)).dx,
      greaterThan(_barCentre(tester)),
    );
  });

  testWidgets('segment width follows kg over scale', (tester) async {
    await _pump(tester, _balance());
    // One half of the bar, less the 2 px centre rule and the room kept for
    // the four gaps a side can have.
    final width = tester.getSize(find.byType(BuoyancyBalanceBar)).width;
    final usable = (width - 2) / 2 - 8;
    // Lead is 6 of a 12 kg scale.
    expect(
      tester.getSize(_segment(TwinBalancePartKind.lead)).width,
      closeTo(usable * 6 / 12, 0.5),
    );
    // Body is 5 of 12.
    expect(
      tester.getSize(_segment(TwinBalancePartKind.body)).width,
      closeTo(usable * 5 / 12, 0.5),
    );
  });

  testWidgets('the constant lead part stays put when tanks change', (
    tester,
  ) async {
    await _pump(tester, _balance(tanks: -2.0));
    final before = tester.getRect(_segment(TwinBalancePartKind.lead));
    await _pump(tester, _balance(tanks: -0.5));
    final after = tester.getRect(_segment(TwinBalancePartKind.lead));
    expect(after, before);
  });

  testWidgets('a wide segment carries its label', (tester) async {
    await _pump(tester, _balance());
    expect(
      find.descendant(
        of: _segment(TwinBalancePartKind.lead),
        matching: find.text('Lead 6.0 kg'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a narrow segment lists its label in the legend', (tester) async {
    await _pump(tester, _balance(suit: 0.3), width: 300);
    expect(tester.takeException(), isNull);
    expect(find.text('Suit 0.3 kg'), findsOneWidget);
    expect(
      find.descendant(
        of: _segment(TwinBalancePartKind.suit),
        matching: find.text('Suit 0.3 kg'),
      ),
      findsNothing,
    );
  });

  testWidgets('a mid-width segment keeps its name and lists the figure', (
    tester,
  ) async {
    // At 400 px the lead segment is about 95 px: room for "Lead", not for
    // "Lead 6.0 kg".
    await _pump(tester, _balance(), width: 400);
    final lead = _segment(TwinBalancePartKind.lead);
    expect(
      find.descendant(of: lead, matching: find.text('Lead')),
      findsOneWidget,
    );
    expect(find.text('Lead 6.0 kg'), findsOneWidget);
    expect(
      find.descendant(of: lead, matching: find.text('Lead 6.0 kg')),
      findsNothing,
    );
  });

  testWidgets('the legend reads in the same order as the bar', (tester) async {
    await _pump(tester, _balance(), width: 300);
    final legend = find.byKey(const ValueKey('balance-legend'));
    final labels = [
      for (final text in tester.widgetList<Text>(
        find.descendant(of: legend, matching: find.byType(Text)),
      ))
        text.data,
    ];
    // Down side from the outer edge in, then up side from the centre out.
    expect(labels, [
      'Cylinders 2.0 kg',
      'Gear 1.0 kg',
      'Lead 6.0 kg',
      'Body 5.0 kg',
      'Suit 3.0 kg',
    ]);
  });

  testWidgets('right to left keeps each caption over its own half', (
    tester,
  ) async {
    const locale = Locale('ar');
    await _pump(tester, _balance(), locale: locale);
    expect(tester.takeException(), isNull);
    final l10n = lookupAppLocalizations(locale);
    final centre = _barCentre(tester);
    final leadX = tester.getCenter(_segment(TwinBalancePartKind.lead)).dx;
    final downCaptionX = tester
        .getCenter(find.text(l10n.buoyancy_pullingDown))
        .dx;
    // Mirrored: the down half is now on the right, and so is its caption.
    expect(leadX, greaterThan(centre));
    expect(downCaptionX, greaterThan(centre));
  });

  testWidgets('imperial settings format the labels in lb', (tester) async {
    await _pump(
      tester,
      _balance(),
      settings: const AppSettings(weightUnit: WeightUnit.pounds),
    );
    expect(find.text('Lead 13.2 lbs'), findsOneWidget);
  });

  testWidgets('each segment has a tooltip naming the part', (tester) async {
    await _pump(tester, _balance());
    expect(find.byTooltip('Lead 6.0 kg'), findsOneWidget);
    expect(find.byTooltip('Body 5.0 kg'), findsOneWidget);
  });
}
