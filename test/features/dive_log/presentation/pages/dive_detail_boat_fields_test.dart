import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #3229: the detail page shows the operator, boat and captain in
/// Details, and surface conditions under Environment > Dive conditions.
void main() {
  /// The detail page renders a profile chart that can overflow an
  /// unconstrained test viewport. Ignore only that, and forward everything
  /// else, so a real rendering failure still fails the test.
  void ignoreOverflowErrors() {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
  }

  Future<void> pumpWith(WidgetTester tester, Dive dive) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(const AppSettings()),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveProvider(dive.id).overrideWith((ref) async => dive),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );

    ignoreOverflowErrors();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder row(String label, String value) => find.ancestor(
    of: find.text(value),
    matching: find.widgetWithText(DiveDetailRow, label),
  );

  testWidgets('shows operator, boat and captain rows', (tester) async {
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(
        diveOperator: 'Buddy Dive',
        boatName: 'Bonaire Breeze',
        boatCaptain: 'Rik',
      ),
    );

    expect(row('Operator', 'Buddy Dive'), findsOneWidget);
    expect(row('Boat', 'Bonaire Breeze'), findsOneWidget);
    expect(row('Captain', 'Rik'), findsOneWidget);
  });

  testWidgets('no rows for empty or blank values', (tester) async {
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(boatName: '   '),
    );

    expect(find.widgetWithText(DiveDetailRow, 'Operator'), findsNothing);
    expect(find.widgetWithText(DiveDetailRow, 'Boat'), findsNothing);
    expect(find.widgetWithText(DiveDetailRow, 'Captain'), findsNothing);
  });

  testWidgets('surface conditions alone opens Dive conditions', (tester) async {
    // The Environment card is hidden unless something in it has a value,
    // so the card gate and the subsection gate must both count it.
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(surfaceConditions: 'Choppy'),
    );

    expect(row('Surface Conditions', 'Choppy'), findsOneWidget);
    expect(find.text('Dive Conditions'), findsOneWidget);
  });
}
