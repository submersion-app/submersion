import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  /// Pumps a host with one button that opens the sheet, and returns a
  /// getter for whatever the sheet eventually hands back.
  Future<SiteFeatureSheetResult? Function()> pumpHost(
    WidgetTester tester, {
    SiteFeature? existing,
    double? initialDepthMeters,
    AppSettings settings = const AppSettings(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    SiteFeatureSheetResult? captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  captured = await showSiteFeatureSheet(
                    context,
                    existing: existing,
                    initialDepthMeters: initialDepthMeters,
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return () => captured;
  }

  testWidgets('save flow returns the draft with metric depth', (tester) async {
    final result = await pumpHost(tester, initialDepthMeters: 18.0);

    // Depth pre-fills in the diver's unit (metric here).
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('siteFeatureDepthField')),
          )
          .initialValue,
      '18',
    );

    await tester.tap(find.byKey(const ValueKey('siteFeatureTypeField')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Mooring').last);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const ValueKey('siteFeatureNameField')),
      'North ball',
    );
    await tester.enterText(
      find.byKey(const ValueKey('siteFeatureBearingField')),
      '90',
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result(), isA<SiteFeatureSheetSave>());
    final save = result()! as SiteFeatureSheetSave;
    expect(save.typeName, 'mooring');
    expect(save.name, 'North ball');
    expect(save.bearingDeg, 90);
    expect(save.depthMeters, 18);
  });

  testWidgets('bearings normalize into 0-359, including negatives', (
    tester,
  ) async {
    final result = await pumpHost(tester);
    await tester.enterText(
      find.byKey(const ValueKey('siteFeatureBearingField')),
      '-10',
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dart's % is euclidean: -10 lands at 350, not -10.
    expect((result()! as SiteFeatureSheetSave).bearingDeg, 350);
  });

  testWidgets('an over-rotated bearing wraps into range', (tester) async {
    final result = await pumpHost(tester);
    await tester.enterText(
      find.byKey(const ValueKey('siteFeatureBearingField')),
      '370',
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect((result()! as SiteFeatureSheetSave).bearingDeg, 10);
  });

  testWidgets('blank optional fields come back null, not zero', (tester) async {
    final result = await pumpHost(tester);
    await tester.tap(find.byKey(const ValueKey('siteFeatureSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final save = result()! as SiteFeatureSheetSave;
    expect(save.bearingDeg, isNull);
    expect(save.depthMeters, isNull);
    expect(save.name, '');
    expect(save.notes, '');
    // The default type is the first of the vocabulary.
    expect(save.typeName, 'wreck');
  });

  testWidgets('dismissing the sheet writes nothing', (tester) async {
    final result = await pumpHost(tester);
    // Pop without saving, the way a drag-down or back gesture would.
    Navigator.of(tester.element(find.text('OPEN'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result(), isNull);
  });

  testWidgets('an unknown stored type survives an unrelated edit', (
    tester,
  ) async {
    final result = await pumpHost(
      tester,
      existing: const SiteFeature(
        id: 'f-9',
        siteId: 's-1',
        // A type from a newer app version this build does not know.
        typeName: 'lavaTube',
        latitude: 12.15,
        longitude: -68.3,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('siteFeatureNameField')),
      'Renamed',
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final save = result()! as SiteFeatureSheetSave;
    expect(save.typeName, 'lavaTube');
    expect(save.name, 'Renamed');
  });

  testWidgets('cancelling the delete dialog keeps the sheet open', (
    tester,
  ) async {
    final result = await pumpHost(
      tester,
      existing: const SiteFeature(
        id: 'f-1',
        siteId: 's-1',
        typeName: 'wreck',
        latitude: 12.15,
        longitude: -68.3,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('siteFeatureDeleteButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // An unnamed feature is identified by its type label.
    expect(find.text('Delete Wreck?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result(), isNull);
    expect(find.byKey(const ValueKey('siteFeatureSaveButton')), findsOneWidget);
  });

  testWidgets('a feet diver sees and edits depth in feet', (tester) async {
    final result = await pumpHost(
      tester,
      initialDepthMeters: 3.048,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('siteFeatureDepthField')),
          )
          .initialValue,
      '10',
    );

    await tester.enterText(
      find.byKey(const ValueKey('siteFeatureDepthField')),
      '20',
    );
    await tester.tap(find.byKey(const ValueKey('siteFeatureSaveButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final save = result()! as SiteFeatureSheetSave;
    expect(save.depthMeters, closeTo(6.096, 1e-9));
  });

  testWidgets('edit flow offers delete and returns the sentinel', (
    tester,
  ) async {
    final result = await pumpHost(
      tester,
      existing: const SiteFeature(
        id: 'f-1',
        siteId: 's-1',
        typeName: 'wreck',
        name: 'Hilma Hooker',
        latitude: 12.15,
        longitude: -68.3,
      ),
    );

    expect(find.text('Edit feature'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('siteFeatureDeleteButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Confirmation names the feature.
    expect(find.text('Delete Hilma Hooker?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('siteFeatureDeleteConfirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result(), isA<SiteFeatureSheetDelete>());
  });
}
