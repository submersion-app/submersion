import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// The dive computer face on a consolidated dive reads the gas the SELECTED
/// computer was breathing (#4300). Both computers recorded the same switch to
/// EAN50, B at 100 s and A at 200 s; a photo at 150 s on A's profile must read
/// Air, as A's chart gas strip does, not B's earlier switch.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({'perdix_overlay_enabled': true});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  MediaItem photoAt(int elapsedSeconds) => MediaItem(
    id: 'm1',
    diveId: 'd1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'g1',
    takenAt: DateTime.utc(2026, 7, 1, 10),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
    enrichment: MediaEnrichment(
      id: 'e1',
      mediaId: 'm1',
      diveId: 'd1',
      elapsedSeconds: elapsedSeconds,
      depthMeters: 15.0,
      matchConfidence: MatchConfidence.exact,
      createdAt: DateTime.utc(2026, 7, 1),
    ),
  );

  const profileA = [
    domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
    domain.DiveProfilePoint(timestamp: 120, depth: 20.0),
    domain.DiveProfilePoint(timestamp: 150, depth: 15.0),
    domain.DiveProfilePoint(timestamp: 240, depth: 5.0),
  ];
  const profileB = [
    domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
    domain.DiveProfilePoint(timestamp: 120, depth: 21.0),
    domain.DiveProfilePoint(timestamp: 150, depth: 16.0),
    domain.DiveProfilePoint(timestamp: 240, depth: 6.0),
  ];

  final dive = domain.Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 7, 1, 9, 30),
    diveMode: DiveMode.oc,
    profile: profileA,
    tanks: const [
      domain.DiveTank(
        id: 'air',
        computerId: 'computer-a',
        sharedComputerIds: ['computer-b'],
        gasMix: domain.GasMix(o2: 21),
        order: 0,
      ),
      domain.DiveTank(
        id: 'deco',
        computerId: 'computer-a',
        sharedComputerIds: ['computer-b'],
        gasMix: domain.GasMix(o2: 50),
        role: TankRole.deco,
        order: 1,
      ),
    ],
  );

  GasSwitchWithTank change(String computer, int time) => GasSwitchWithTank(
    gasSwitch: GasSwitch(
      id: 'switch-$computer',
      diveId: 'd1',
      timestamp: time,
      tankId: 'deco',
      computerId: computer,
      createdAt: DateTime.utc(2026),
    ),
    tankName: 'EAN50 deco',
    gasMix: 'EAN50',
    o2Fraction: 0.5,
  );

  final sources = [
    DiveDataSource(
      id: 's-a',
      diveId: 'd1',
      computerId: 'computer-a',
      isPrimary: true,
      importedAt: DateTime.utc(2026, 7, 1),
      createdAt: DateTime.utc(2026, 7, 1),
    ),
    DiveDataSource(
      id: 's-b',
      diveId: 'd1',
      computerId: 'computer-b',
      isPrimary: false,
      importedAt: DateTime.utc(2026, 7, 1),
      createdAt: DateTime.utc(2026, 7, 1),
    ),
  ];

  Future<String?> faceGasAt(WidgetTester tester, int elapsedSeconds) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            diveProvider('d1').overrideWith((ref) async => dive),
            diveDataSourcesProvider('d1').overrideWith((ref) async => sources),
            sourceProfilesProvider('d1').overrideWith(
              (ref) async => const {
                's-a': SourceProfile(
                  sourceId: 's-a',
                  computerId: 'computer-a',
                  isEdited: false,
                  points: profileA,
                ),
                's-b': SourceProfile(
                  sourceId: 's-b',
                  computerId: 'computer-b',
                  isEdited: false,
                  points: profileB,
                ),
              },
            ),
            gasSwitchesProvider('d1').overrideWith(
              (ref) async => [
                change('computer-b', 100),
                change('computer-a', 200),
              ],
            ),
            activeSourceTankPressuresProvider(
              'd1',
            ).overrideWith((ref) async => const {}),
            sourceProfileAnalysisProvider.overrideWith(
              (ref, key) async => null,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(
              mediaList: [photoAt(elapsedSeconds)],
              initialMediaId: 'm1',
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    return tester.widget<PerdixFace>(find.byType(PerdixFace)).data.gasLabel;
  }

  testWidgets('another computer\'s earlier switch leaves the gas on Air', (
    tester,
  ) async {
    expect(await faceGasAt(tester, 150), 'Air');
  });

  testWidgets('the selected computer\'s own switch moves the gas', (
    tester,
  ) async {
    expect(await faceGasAt(tester, 230), 'EAN50');
  });
}
