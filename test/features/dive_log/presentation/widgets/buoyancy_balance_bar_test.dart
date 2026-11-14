import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
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
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
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

Finder _swatch(TwinBalancePartKind kind) =>
    find.byKey(ValueKey('balance-legend-${kind.name}'));

Color _fill(WidgetTester tester, Finder box) =>
    (tester.widget<Container>(box).decoration! as BoxDecoration).color!;

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

  testWidgets('slivers beside a full side shrink to fit, not overflow', (
    tester,
  ) async {
    // Lead alone fills the 6 kg scale; two slivers each take their 2 px
    // minimum on top of it, which would push the side past its half.
    const parts = [
      TwinBalancePart(kind: TwinBalancePartKind.lead, kg: -6.0),
      TwinBalancePart(kind: TwinBalancePartKind.tanks, kg: -0.06),
      TwinBalancePart(kind: TwinBalancePartKind.gear, kg: -0.06),
    ];
    await _pump(
      tester,
      const TwinBalance(parts: parts, netKg: -6.12),
      scaleKg: 6.0,
    );
    expect(tester.takeException(), isNull);
    final half =
        (tester.getSize(find.byType(BuoyancyBalanceBar)).width - 2) / 2;
    final used = [
      for (final part in parts) tester.getSize(_segment(part.kind)).width,
    ].fold(0.0, (sum, w) => sum + w);
    // Unshrunk they would total the usable width plus 4 px. Shrunk, they fit
    // the usable width exactly: the half less the room kept for four gaps.
    expect(used, closeTo(half - 8, 0.01));
  });

  testWidgets('a bar squeezed to almost nothing draws no segments', (
    tester,
  ) async {
    // 21 px leaves under 2 px of usable half width: less than one segment's
    // minimum, which used to make the width clamp throw.
    await _pump(tester, _balance(), width: 21);
    expect(tester.takeException(), isNot(isA<ArgumentError>()));
    expect(_segment(TwinBalancePartKind.lead), findsNothing);
  });

  group('telling the parts apart', () {
    testWidgets('a segment too narrow for its name shows its icon', (
      tester,
    ) async {
      // At 400 px the suit segment is about 48 px: too narrow for "Suit" in
      // the test font, wide enough for an icon.
      await _pump(tester, _balance(), width: 400);
      final suit = _segment(TwinBalancePartKind.suit);
      expect(
        find.descendant(of: suit, matching: find.text('Suit')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: suit,
          matching: find.byIcon(SubmersionIcons.wetsuit),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a 20 px segment still has room for its icon', (tester) async {
      // 430 px is a phone; 1.4 kg of cylinder at a 12 kg scale is about 24 px
      // of the 205 px usable half, and 1.2 kg about 20 px.
      await _pump(tester, _balance(tanks: -1.2), width: 430);
      final tanks = _segment(TwinBalancePartKind.tanks);
      expect(tester.getSize(tanks).width, inInclusiveRange(18.0, 22.0));
      expect(
        find.descendant(
          of: tanks,
          matching: find.byIcon(SubmersionIcons.tankBackGas),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a sliver too narrow for an icon stays bare', (tester) async {
      await _pump(tester, _balance(suit: 0.3), width: 300);
      expect(
        find.descendant(
          of: _segment(TwinBalancePartKind.suit),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('each legend entry carries its part icon and its shade', (
      tester,
    ) async {
      await _pump(tester, _balance(), width: 300);
      for (final (kind, icon) in [
        (TwinBalancePartKind.lead, SubmersionIcons.weightPocket),
        (TwinBalancePartKind.tanks, SubmersionIcons.tankBackGas),
        (TwinBalancePartKind.gear, SubmersionIcons.bcd),
        (TwinBalancePartKind.suit, SubmersionIcons.wetsuit),
        (TwinBalancePartKind.body, Icons.accessibility_new),
      ]) {
        expect(
          find.descendant(of: _swatch(kind), matching: find.byIcon(icon)),
          findsOneWidget,
          reason: kind.name,
        );
        expect(
          _fill(tester, _swatch(kind)),
          _fill(tester, _segment(kind)),
          reason: kind.name,
        );
      }
    });

    testWidgets('parts on the same side have different shades', (tester) async {
      await _pump(tester, _balance());
      final down = {
        for (final kind in [
          TwinBalancePartKind.lead,
          TwinBalancePartKind.gear,
          TwinBalancePartKind.tanks,
        ])
          _fill(tester, _segment(kind)),
      };
      expect(down, hasLength(3));
      expect(
        _fill(tester, _segment(TwinBalancePartKind.body)),
        isNot(_fill(tester, _segment(TwinBalancePartKind.suit))),
      );
    });

    for (final (name, theme) in [
      ('light', ThemeData(brightness: Brightness.light)),
      ('dark', ThemeData(brightness: Brightness.dark)),
    ]) {
      testWidgets('labels stay readable on every shade ($name)', (
        tester,
      ) async {
        await _pump(tester, _balance(), theme: theme);
        for (final kind in TwinBalancePartKind.values) {
          final segment = _segment(kind);
          // Whatever the segment has room for: its text or its icon.
          final texts = tester.widgetList<Text>(
            find.descendant(of: segment, matching: find.byType(Text)),
          );
          final icons = tester.widgetList<Icon>(
            find.descendant(of: segment, matching: find.byType(Icon)),
          );
          final ink = texts.isNotEmpty
              ? texts.single.style!.color!
              : icons.single.color!;
          expect(
            contrastRatio(ink, _fill(tester, segment)),
            greaterThanOrEqualTo(4.5),
            reason: '$name ${kind.name}',
          );
        }
      });
    }
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

  testWidgets('a screen reader hears which side each part is on', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _balance());
    expect(
      find.bySemanticsLabel('Pulling you down: Lead 6.0 kg'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Holding you up: Body 5.0 kg'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('each segment has a tooltip naming the part', (tester) async {
    await _pump(tester, _balance());
    expect(find.byTooltip('Lead 6.0 kg'), findsOneWidget);
    expect(find.byTooltip('Body 5.0 kg'), findsOneWidget);
  });
}
