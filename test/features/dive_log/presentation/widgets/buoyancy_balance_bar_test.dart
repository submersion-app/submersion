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
  Map<TwinBalancePartKind, (double, double)>? ranges,
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
          partRangesKg: ranges,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _segment(TwinBalancePartKind kind) =>
    find.byKey(ValueKey('balance-${kind.name}'));

Finder _callout(TwinBalancePartKind kind) =>
    find.byKey(ValueKey('balance-callout-${kind.name}'));

Finder _heading(String side) => find.byKey(ValueKey('balance-heading-$side'));

String _headingText(WidgetTester tester, String side) =>
    tester.widget<Text>(_heading(side)).textSpan!.toPlainText();

Finder _rulerLabel(String text) => find.descendant(
  of: find.byKey(const ValueKey('balance-ruler')),
  matching: find.text(text),
);

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

  testWidgets('a narrow segment floats its label in a callout above it', (
    tester,
  ) async {
    await _pump(tester, _balance(suit: 0.3), width: 300);
    expect(tester.takeException(), isNull);
    final suit = _segment(TwinBalancePartKind.suit);
    expect(
      find.descendant(of: suit, matching: find.text('Suit 0.3 kg')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _callout(TwinBalancePartKind.suit),
        matching: find.text('Suit 0.3 kg'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(_callout(TwinBalancePartKind.suit)).bottom,
      lessThanOrEqualTo(tester.getRect(suit).top),
    );
  });

  testWidgets('a segment too narrow for its label shows its icon and a '
      'callout', (tester) async {
    // At 400 px the lead segment is about 95 px: too narrow for
    // "Lead 6.0 kg" in the test font.
    await _pump(tester, _balance(), width: 400);
    final lead = _segment(TwinBalancePartKind.lead);
    expect(
      find.descendant(of: lead, matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: lead,
        matching: find.byIcon(SubmersionIcons.weightPocket),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _callout(TwinBalancePartKind.lead),
        matching: find.text('Lead 6.0 kg'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a wide segment that carries its label has no callout', (
    tester,
  ) async {
    await _pump(tester, _balance());
    expect(_callout(TwinBalancePartKind.lead), findsNothing);
  });

  testWidgets('a lone callout sits right over its segment', (tester) async {
    const parts = [
      TwinBalancePart(kind: TwinBalancePartKind.lead, kg: -6.0),
      TwinBalancePart(kind: TwinBalancePartKind.suit, kg: 0.3),
      TwinBalancePart(kind: TwinBalancePartKind.body, kg: 5.0),
    ];
    await _pump(tester, const TwinBalance(parts: parts, netKg: -0.7));
    expect(
      tester.getCenter(_callout(TwinBalancePartKind.suit)).dx,
      closeTo(tester.getCenter(_segment(TwinBalancePartKind.suit)).dx, 0.5),
    );
  });

  testWidgets('callouts read in the same order as the bar', (tester) async {
    // At 800 px the cylinders, gear and suit segments are too narrow for
    // their labels in the test font; lead and body carry theirs.
    await _pump(tester, _balance());
    final xs = [
      for (final kind in [
        TwinBalancePartKind.tanks,
        TwinBalancePartKind.gear,
        TwinBalancePartKind.suit,
      ])
        tester.getCenter(_callout(kind)).dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));
  });

  testWidgets('a callout is outlined in its side colour', (tester) async {
    final theme = ThemeData(brightness: Brightness.light);
    await _pump(tester, _balance(), theme: theme);
    Color outline(TwinBalancePartKind kind) =>
        ((tester.widget<Container>(_callout(kind)).decoration! as BoxDecoration)
                    .border!
                as Border)
            .top
            .color;
    expect(outline(TwinBalancePartKind.tanks), theme.colorScheme.tertiary);
    expect(outline(TwinBalancePartKind.suit), theme.colorScheme.primary);
  });

  testWidgets('the bar stays put whether or not parts need callouts', (
    tester,
  ) async {
    // Lead and body alone both carry their labels at 800 px: no callouts.
    const plain = [
      TwinBalancePart(kind: TwinBalancePartKind.lead, kg: -6.0),
      TwinBalancePart(kind: TwinBalancePartKind.body, kg: 5.0),
    ];
    await _pump(tester, const TwinBalance(parts: plain, netKg: -1.0));
    expect(find.byKey(const ValueKey('balance-callout-lead')), findsNothing);
    final before = tester.getRect(_segment(TwinBalancePartKind.lead)).top;
    await _pump(tester, _balance());
    expect(_callout(TwinBalancePartKind.suit), findsOneWidget);
    expect(tester.getRect(_segment(TwinBalancePartKind.lead)).top, before);
  });

  testWidgets('with the dive ranges the bar holds still when a second row of '
      'callouts appears', (tester) async {
    // On a 300 px phone, lead and body alone need one row of callouts; with
    // every part a sliver they need two.
    const plain = [
      TwinBalancePart(kind: TwinBalancePartKind.lead, kg: -6.0),
      TwinBalancePart(kind: TwinBalancePartKind.body, kg: 5.0),
    ];
    const ranges = {
      TwinBalancePartKind.lead: (6.0, 6.0),
      TwinBalancePartKind.tanks: (2.0, 2.0),
      TwinBalancePartKind.gear: (1.0, 1.0),
      TwinBalancePartKind.suit: (0.3, 3.0),
      TwinBalancePartKind.body: (5.0, 5.0),
    };
    Future<double> leadTop(
      TwinBalance b, {
      Map<TwinBalancePartKind, (double, double)>? r,
    }) async {
      await _pump(tester, b, width: 300, ranges: r);
      return tester.getRect(_segment(TwinBalancePartKind.lead)).top;
    }

    const one = TwinBalance(parts: plain, netKg: -1.0);
    final crowded = _balance(suit: 0.3);
    // Without the ranges the lane grows, which is the jump being prevented.
    expect(await leadTop(crowded), greaterThan(await leadTop(one)));
    // With them it already has the room.
    expect(await leadTop(crowded, r: ranges), await leadTop(one, r: ranges));
  });

  testWidgets('a callout does not repeat its part to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _balance());
    expect(find.bySemanticsLabel('Suit 3.0 kg'), findsNothing);
    expect(
      find.bySemanticsLabel('Holding you up: Suit 3.0 kg'),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('headings', () {
    testWidgets('each side has its arrow', (tester) async {
      await _pump(tester, _balance());
      expect(
        find.descendant(
          of: _heading('down'),
          matching: find.byIcon(Icons.arrow_downward),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _heading('up'),
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
      );
    });

    testWidgets('each side names its total', (tester) async {
      // Down: 6 lead, 2 cylinders, 1 gear. Up: 3 suit, 5 body.
      await _pump(tester, _balance());
      expect(_headingText(tester, 'down'), contains('Pulling you down'));
      expect(_headingText(tester, 'down'), contains('9.0 kg'));
      expect(_headingText(tester, 'up'), contains('Holding you up'));
      expect(_headingText(tester, 'up'), contains('8.0 kg'));
    });

    testWidgets('the totals follow the diver unit', (tester) async {
      await _pump(
        tester,
        _balance(),
        settings: const AppSettings(weightUnit: WeightUnit.pounds),
      );
      expect(_headingText(tester, 'down'), contains('19.8 lbs'));
    });
  });

  group('ruler', () {
    testWidgets('marks round weights out from the centre on both sides', (
      tester,
    ) async {
      await _pump(tester, _balance());
      expect(_rulerLabel('0'), findsOneWidget);
      expect(_rulerLabel('5 kg'), findsNWidgets(2));
      expect(_rulerLabel('10 kg'), findsNWidgets(2));
    });

    testWidgets('a mark sits where a part of that weight would end', (
      tester,
    ) async {
      await _pump(tester, _balance());
      final width = tester.getSize(find.byType(BuoyancyBalanceBar)).width;
      final half = (width - 2) / 2;
      final usable = half - 8;
      final xs = [
        for (final e in tester.widgetList(_rulerLabel('10 kg')))
          tester.getCenter(find.byWidget(e)).dx,
      ]..sort();
      // The scale is 12 kg, so 10 kg is ten twelfths of the usable half out
      // from the rule.
      expect(xs.first, closeTo(half - usable * 10 / 12, 0.5));
      expect(xs.last, closeTo(half + 2 + usable * 10 / 12, 0.5));
    });

    testWidgets('pounds get their own round marks', (tester) async {
      await _pump(
        tester,
        _balance(),
        settings: const AppSettings(weightUnit: WeightUnit.pounds),
      );
      // 12 kg is 26.5 lb.
      expect(_rulerLabel('10 lbs'), findsNWidgets(2));
      expect(_rulerLabel('20 lbs'), findsNWidgets(2));
    });

    testWidgets('a narrow bar gets fewer marks, none overlapping', (
      tester,
    ) async {
      await _pump(tester, _balance(), width: 300);
      expect(tester.takeException(), isNull);
      final rects = [
        for (final e in tester.widgetList(
          find.descendant(
            of: find.byKey(const ValueKey('balance-ruler')),
            matching: find.byType(Text),
          ),
        ))
          tester.getRect(find.byWidget(e)),
      ]..sort((a, b) => a.left.compareTo(b.left));
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      }
    });
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

    testWidgets('gear that floats does not share the suit shade', (
      tester,
    ) async {
      // Buoyant gear sits on the up side, where the suit already is.
      const parts = [
        TwinBalancePart(kind: TwinBalancePartKind.lead, kg: -6.0),
        TwinBalancePart(kind: TwinBalancePartKind.gear, kg: 1.5),
        TwinBalancePart(kind: TwinBalancePartKind.suit, kg: 3.0),
        TwinBalancePart(kind: TwinBalancePartKind.body, kg: 5.0),
      ];
      await _pump(tester, const TwinBalance(parts: parts, netKg: 3.5));
      final up = {
        for (final kind in [
          TwinBalancePartKind.body,
          TwinBalancePartKind.gear,
          TwinBalancePartKind.suit,
        ])
          _fill(tester, _segment(kind)),
      };
      expect(up, hasLength(3));
    });

    testWidgets('a body that sinks does not share the lead shade', (
      tester,
    ) async {
      const parts = [
        TwinBalancePart(kind: TwinBalancePartKind.lead, kg: -6.0),
        TwinBalancePart(kind: TwinBalancePartKind.suit, kg: 3.0),
        TwinBalancePart(kind: TwinBalancePartKind.body, kg: -2.0),
      ];
      await _pump(tester, const TwinBalance(parts: parts, netKg: -5.0));
      expect(
        _fill(tester, _segment(TwinBalancePartKind.body)),
        isNot(_fill(tester, _segment(TwinBalancePartKind.lead))),
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
    expect(_headingText(tester, 'down'), contains(l10n.buoyancy_pullingDown));
    final downCaptionX = tester.getCenter(_heading('down')).dx;
    // Mirrored: the down half is now on the right, and so is its caption.
    expect(leadX, greaterThan(centre));
    expect(downCaptionX, greaterThan(centre));
  });

  testWidgets('right to left mirrors the callouts with their segments', (
    tester,
  ) async {
    await _pump(tester, _balance(), locale: const Locale('ar'));
    final suit = _segment(TwinBalancePartKind.suit);
    expect(tester.getCenter(suit).dx, lessThan(_barCentre(tester)));
    expect(
      tester.getCenter(_callout(TwinBalancePartKind.suit)).dx,
      lessThan(_barCentre(tester)),
    );
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
