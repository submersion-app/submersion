import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/first_day_of_week.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records the first day of the week the page asks to persist. Everything
/// else falls through to noSuchMethod.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettingsNotifier(super.settings);

  final List<FirstDayOfWeek> saved = [];

  @override
  Future<void> setFirstDayOfWeek(FirstDayOfWeek day) async {
    saved.add(day);
    state = state.copyWith(firstDayOfWeek: day);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #4232: the Units page groups each setting with what it belongs to,
/// and offers the first day of the week under Time & Date.
void main() {
  late _RecordingSettingsNotifier notifier;

  Widget host(AppSettings settings) {
    notifier = _RecordingSettingsNotifier(settings);
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        // Pinned: the finders match English strings, and English alone
        // starts the week on Sunday.
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsSectionDetailPage(sectionId: 'units'),
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester, [AppSettings? settings]) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(settings ?? const AppSettings()));
    await tester.pumpAndSettle();
  }

  /// The card holding [title].
  Finder cardOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Card)).first;

  bool inCard(String card, String title) => find
      .descendant(of: cardOf(card), matching: find.text(title))
      .evaluate()
      .isNotEmpty;

  testWidgets('the quick select shares a card with the seven units it sets', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Applies to the following units'), findsOneWidget);
    for (final unit in [
      'Depth',
      'Temperature',
      'Pressure',
      'Volume',
      'Weight',
      'Altitude',
      'Distance',
    ]) {
      expect(inCard('Quick Select', unit), isTrue, reason: unit);
    }
    for (final other in [
      'Gas consumption',
      'Default Currency',
      'Coordinate format',
      'Time Format',
    ]) {
      expect(inCard('Quick Select', other), isFalse, reason: other);
    }
  });

  testWidgets('the other settings sit under their own headings', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Gas & Planning'), findsOneWidget);
    expect(find.text('Display & Formats'), findsOneWidget);
    expect(find.text('Time & Date'), findsOneWidget);
    expect(find.text('Individual Units'), findsNothing);

    expect(inCard('Gas consumption', 'Unit follows pressure and volume'), true);
    expect(inCard('Coordinate format', 'Default Currency'), isTrue);
    expect(inCard('Time Format', 'First day of week'), isTrue);
  });

  testWidgets('automatic names the day the week starts on', (tester) async {
    await pumpPage(tester);
    expect(find.text('Automatic (Sunday)'), findsOneWidget);
  });

  testWidgets('choosing Monday persists it and closes the dialog', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('First day of week'));
    await tester.pumpAndSettle();

    expect(find.text('First Day of Week'), findsOneWidget);
    expect(find.text("Follows your device's region"), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();

    expect(notifier.saved, [FirstDayOfWeek.monday]);
    expect(find.text('First Day of Week'), findsNothing);
    expect(find.text('Monday'), findsOneWidget);
  });

  testWidgets('the dialog ticks the current choice', (tester) async {
    await pumpPage(
      tester,
      const AppSettings(firstDayOfWeek: FirstDayOfWeek.saturday),
    );
    expect(find.text('Saturday'), findsOneWidget);
    await tester.tap(find.text('First day of week'));
    await tester.pumpAndSettle();

    final saturday = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Saturday').last,
        matching: find.byType(ListTile),
      ),
    );
    expect(saturday.trailing, isA<Icon>());
  });
}
