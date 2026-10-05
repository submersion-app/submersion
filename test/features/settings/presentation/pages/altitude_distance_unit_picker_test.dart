import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records what the pickers ask the notifier to persist, without touching
/// the database. Everything else falls through to noSuchMethod.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettingsNotifier(super.settings);

  final List<Object> saved = [];

  @override
  Future<void> setAltitudeUnit(AltitudeUnit unit) async {
    saved.add(unit);
    state = state.copyWith(altitudeUnit: unit);
  }

  @override
  Future<void> setDistanceUnit(DistanceUnit unit) async {
    saved.add(unit);
    state = state.copyWith(distanceUnit: unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingSettingsNotifier notifier;

  Widget host(AppSettings settings) {
    notifier = _RecordingSettingsNotifier(settings);
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        // Pinned: the finders match English strings.
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsSectionDetailPage(sectionId: 'units'),
      ),
    );
  }

  Future<void> openTile(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(find.text(title), 50.0);
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  group('distance unit (issue #2030)', () {
    testWidgets('the tile shows the active unit', (tester) async {
      await tester.pumpWidget(
        host(const AppSettings(distanceUnit: DistanceUnit.miles)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Distance'), 50.0);
      await tester.pumpAndSettle();
      expect(find.text('mi'), findsOneWidget);
    });

    testWidgets('choosing miles persists it and closes the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppSettings()));
      await tester.pumpAndSettle();
      await openTile(tester, 'Distance');

      expect(find.text('Distance Unit'), findsOneWidget);
      expect(find.text('Kilometers (km)'), findsOneWidget);
      await tester.tap(find.text('Miles (mi)'));
      await tester.pumpAndSettle();

      expect(notifier.saved, [DistanceUnit.miles]);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('altitude unit', () {
    testWidgets('the tile shows the active unit', (tester) async {
      await tester.pumpWidget(
        host(const AppSettings(altitudeUnit: AltitudeUnit.feet)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Altitude'), 50.0);
      await tester.pumpAndSettle();
      // Depth stays metres, so the only "ft" on the page is altitude's.
      expect(find.text('ft'), findsOneWidget);
    });

    testWidgets('choosing feet persists it and closes the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppSettings()));
      await tester.pumpAndSettle();
      await openTile(tester, 'Altitude');

      expect(find.text('Altitude Unit'), findsOneWidget);
      await tester.tap(find.text('Feet (ft)'));
      await tester.pumpAndSettle();

      expect(notifier.saved, [AltitudeUnit.feet]);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
