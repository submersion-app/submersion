// `hide Visibility`: flutter/material.dart exports a Visibility widget that
// collides with the app's Visibility enum.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #2055: the Details card read only the pre-v144 visibility bucket, so
/// every dive whose visibility was entered as a measured distance (which the
/// repository stores with the bucket cleared) showed no visibility at all.
void main() {
  const settings = AppSettings();

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
            (ref) => MockSettingsNotifier(settings),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveProvider(dive.id).overrideWith((ref) async => dive),
        ],
        child: MaterialApp(
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

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(DiveDetailPage)));

  Finder visibilityRow(AppLocalizations l10n) =>
      find.widgetWithText(DiveDetailRow, l10n.diveLog_detail_label_visibility);

  testWidgets('a measured-only dive shows its measured visibility', (
    tester,
  ) async {
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(visibilityMeters: 12),
    );

    final l10n = l10nOf(tester);
    final expected = formatMeasuredVisibility(
      12,
      settings.visibilityScale,
      l10n,
      const UnitFormatter(settings),
    );
    expect(visibilityRow(l10n), findsOneWidget);
    expect(find.widgetWithText(DiveDetailRow, expected), findsOneWidget);
  });

  testWidgets('a pre-v144 dive still shows its legacy bucket', (tester) async {
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(visibility: Visibility.moderate),
    );

    final l10n = l10nOf(tester);
    expect(
      find.widgetWithText(
        DiveDetailRow,
        visibilityName(Visibility.moderate, l10n),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a dive with no visibility shows no visibility row', (
    tester,
  ) async {
    await pumpWith(tester, createTestDiveWithBottomTime());

    expect(visibilityRow(l10nOf(tester)), findsNothing);
  });
}
