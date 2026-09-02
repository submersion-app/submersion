import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/statistics_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Statistics section is the collapsible group at the bottom of the dive
/// form that owns the two exclusion toggles. Two things matter: the collapsed
/// header has to say whether this dive is excluded (otherwise the exclusion is
/// invisible), and the gas toggle has to read as checked and inert while the
/// master flag is on, so the implication is visible rather than silently
/// overriding what the diver picked.
void main() {
  Widget host({
    required bool excludedFromStats,
    required bool excludedFromGasStats,
    bool expanded = true,
    VoidCallback? onToggle,
    ValueChanged<bool>? onStats,
    ValueChanged<bool>? onGas,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatisticsSection(
            expanded: expanded,
            onToggle: onToggle ?? () {},
            excludedFromStats: excludedFromStats,
            excludedFromGasStats: excludedFromGasStats,
            onExcludedFromStatsChanged: onStats ?? (_) {},
            onExcludedFromGasStatsChanged: onGas ?? (_) {},
          ),
        ),
      ),
    );
  }

  Switch switchAt(WidgetTester tester, Key key) {
    return tester.widget<Switch>(
      find.descendant(of: find.byKey(key), matching: find.byType(Switch)),
    );
  }

  testWidgets('both toggles start off and are interactive', (tester) async {
    await tester.pumpWidget(
      host(excludedFromStats: false, excludedFromGasStats: false),
    );
    await tester.pumpAndSettle();

    final stats = switchAt(tester, const Key('dive-edit-exclude-from-stats'));
    final gas = switchAt(tester, const Key('dive-edit-exclude-from-gas-stats'));
    expect(stats.value, isFalse);
    expect(gas.value, isFalse);
    expect(gas.onChanged, isNotNull);
  });

  testWidgets('the gas toggle reads checked and inert under the master flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(excludedFromStats: true, excludedFromGasStats: false),
    );
    await tester.pumpAndSettle();

    final gas = switchAt(tester, const Key('dive-edit-exclude-from-gas-stats'));
    expect(
      gas.value,
      isTrue,
      reason:
          'it must show the effective state: excluding a dive from all '
          'statistics necessarily excludes it from the gas ones',
    );
    expect(
      gas.onChanged,
      isNull,
      reason:
          'inert rather than silently overridden, so the implication is '
          'legible instead of surprising',
    );
  });

  testWidgets('the gas toggle stands alone when the master flag is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(excludedFromStats: false, excludedFromGasStats: true),
    );
    await tester.pumpAndSettle();

    final stats = switchAt(tester, const Key('dive-edit-exclude-from-stats'));
    final gas = switchAt(tester, const Key('dive-edit-exclude-from-gas-stats'));
    expect(stats.value, isFalse, reason: 'the gas flag must not imply master');
    expect(gas.value, isTrue);
    expect(gas.onChanged, isNotNull);
  });

  testWidgets('toggling the master flag reports the new value', (tester) async {
    bool? reported;
    await tester.pumpWidget(
      host(
        excludedFromStats: false,
        excludedFromGasStats: false,
        onStats: (v) => reported = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dive-edit-exclude-from-stats')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(reported, isTrue);
  });

  testWidgets('each toggle renders its explanatory help text', (tester) async {
    await tester.pumpWidget(
      host(excludedFromStats: false, excludedFromGasStats: false),
    );
    await tester.pumpAndSettle();

    // The labels alone do not say the dive count is affected, which is the
    // part that surprises people months later.
    expect(
      find.textContaining('including your dive count'),
      findsOneWidget,
      reason: 'the master toggle must spell out that the count changes too',
    );
    expect(
      find.textContaining('SAC, RMV and gas mix statistics only'),
      findsOneWidget,
      reason: 'the gas toggle must say it is narrower than the master flag',
    );
  });

  testWidgets('the help text is a wrapping paragraph, not a fixed line', (
    tester,
  ) async {
    // The help lines are long, so they must be free to wrap rather than being
    // clipped to one line. Asserted on the widget rather than by measuring
    // overflow: FormRow's own label is not Flexible, so under the test font
    // (one fontSize-wide glyph per character) the ROW overflows at narrow
    // widths independently of anything this feature added.
    await tester.pumpWidget(
      host(excludedFromStats: false, excludedFromGasStats: false),
    );
    await tester.pumpAndSettle();

    final help = tester.widget<Text>(
      find.textContaining('including your dive count'),
    );
    expect(
      help.maxLines,
      isNull,
      reason:
          'an unset maxLines lets the paragraph wrap to as many lines as '
          'the locale needs; German and Hungarian run materially longer',
    );
    expect(help.overflow, anyOf(isNull, TextOverflow.clip));
  });

  group('collapsed', () {
    testWidgets('hides the toggles but keeps the header tappable', (
      tester,
    ) async {
      var toggled = 0;
      await tester.pumpWidget(
        host(
          excludedFromStats: false,
          excludedFromGasStats: false,
          expanded: false,
          onToggle: () => toggled++,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dive-edit-exclude-from-stats')),
        findsNothing,
        reason: 'a collapsed FormSection does not mount its children',
      );
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();
      expect(toggled, 1);
    });

    testWidgets('says the dive is counted when nothing is excluded', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          excludedFromStats: false,
          excludedFromGasStats: false,
          expanded: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Counted in every statistic'), findsOneWidget);
    });

    testWidgets('names the exclusion so it is not hidden by collapsing', (
      tester,
    ) async {
      // Without this the only trace of an excluded dive would be behind a
      // closed section, which is how a diver loses track of why a count is
      // off months later.
      await tester.pumpWidget(
        host(
          excludedFromStats: true,
          excludedFromGasStats: false,
          expanded: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Excluded'), findsOneWidget);

      await tester.pumpWidget(
        host(
          excludedFromStats: false,
          excludedFromGasStats: true,
          expanded: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gas excluded'), findsOneWidget);
    });
  });
}
