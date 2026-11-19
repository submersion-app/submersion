import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/auto_apply_settings_section.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../domain/manifest_fixture.dart';

/// The two settings that let confident matches be tagged with no tap, and
/// choose when those tags log their sightings (issue #4727).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  InstalledPack pack({required double withPlace, required double noPlace}) =>
      InstalledPack(
        manifest: SpeciesPackManifest.parse(
          manifestJson((m) {
            final naming = m['naming']! as Map;
            naming['confidentScore'] = withPlace;
            naming['confidentScoreNoLocation'] = noPlace;
          }),
        ),
        directory: '/pack',
        detectorPaths: const ['/pack/detector.mlpackage'],
        classifierPath: '/pack/classifier.mlpackage',
      );

  Future<void> pump(WidgetTester tester, InstalledPack? installed) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          installedSpeciesPackProvider.overrideWith((ref) async => installed),
          autoApplyProvider.overrideWith((ref) => AutoApplyNotifier(prefs)),
          sightingTimingProvider.overrideWith(
            (ref) => SightingTimingNotifier(prefs),
          ),
        ],
        child: const SingleChildScrollView(child: AutoApplySettingsSection()),
      ),
    );
    await tester.pumpAndSettle();
  }

  SwitchListTile toggle(WidgetTester tester) =>
      tester.widget(find.byKey(const ValueKey('species_id_auto_apply')));

  testWidgets('hidden with no model installed', (tester) async {
    await pump(tester, null);
    expect(find.byKey(const ValueKey('species_id_auto_apply')), findsNothing);
  });

  testWidgets('off and disabled, saying why, while the bars are never', (
    tester,
  ) async {
    await pump(tester, pack(withPlace: 1.01, noPlace: 1.01));

    expect(toggle(tester).value, isFalse);
    expect(toggle(tester).onChanged, isNull);
    expect(
      find.text(
        "The installed model isn't yet sure enough of any species to tag on "
        'its own. Suggestions still appear for you to add.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a bar only with a place enables it, with a note', (
    tester,
  ) async {
    await pump(tester, pack(withPlace: 0.95, noPlace: 1.01));

    expect(toggle(tester).onChanged, isNotNull);
    expect(
      find.textContaining('Only for photos and videos with a location.'),
      findsOneWidget,
    );
  });

  testWidgets('the switch and the timing persist; the timing waits for the '
      'switch', (tester) async {
    await pump(tester, pack(withPlace: 0.95, noPlace: 0.97));
    final straight = find.byKey(const ValueKey('species_id_timing_straight'));

    await tester.tap(straight);
    await tester.pumpAndSettle();
    expect(prefs.getString(SettingsKeys.speciesIdSightingTiming), isNull);

    await tester.tap(find.byKey(const ValueKey('species_id_auto_apply')));
    await tester.pumpAndSettle();
    expect(prefs.getBool(SettingsKeys.speciesIdAutoApply), isTrue);

    await tester.tap(straight);
    await tester.pumpAndSettle();
    expect(
      prefs.getString(SettingsKeys.speciesIdSightingTiming),
      SightingTiming.straightAway.name,
    );
  });

  testWidgets('switched on with the model removed, it can still be switched '
      'off', (tester) async {
    await prefs.setBool(SettingsKeys.speciesIdAutoApply, true);
    await pump(tester, null);

    expect(toggle(tester).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('species_id_auto_apply')));
    await tester.pumpAndSettle();
    expect(prefs.getBool(SettingsKeys.speciesIdAutoApply), isFalse);
  });
}
