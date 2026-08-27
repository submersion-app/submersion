import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/gradient_factor_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart'
    as divers;
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The analysis must report which gradient factors it ran with and where they
/// came from (#1047).
///
/// The shipped diver default is GF 50/85. A dive downloaded from a computer
/// configured to 45/80 was showing 50/85, because the analysis silently
/// substituted the diver's setting whenever the dive carried no GF of its own
/// and nothing downstream could tell the two apart.
late SharedPreferences _prefs;

class _FakeDiverRepository extends divers.DiverRepository {
  @override
  Future<domain.Diver?> getDiverById(String id) async => null;

  @override
  Future<domain.Diver?> getDefaultDiver() async => null;

  @override
  Future<String?> getActiveDiverIdFromSettings() async => null;

  @override
  Future<void> setActiveDiverIdInSettings(String? diverId) async {}
}

class _FakeDiverSettingsRepository extends DiverSettingsRepository {
  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    // Every field at its shipped default, so gfLow/gfHigh are 50/85.
    return const AppSettings(notificationsEnabled: false);
  }

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings,
  ) async {}
}

class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(Ref ref) : super(_FakeDiverSettingsRepository(), ref);
}

List<DiveProfilePoint> _squareProfile() {
  final depths = <double>[0, 15, 30, 30, 30, 30, 15, 5, 0];
  return [
    for (var i = 0; i < depths.length; i++)
      DiveProfilePoint(timestamp: i * 120, depth: depths[i]),
  ];
}

Dive _dive({int? gfLow, int? gfHigh, String? decoAlgorithm}) => Dive(
  id: 'dive-1047',
  dateTime: DateTime.utc(2026, 1, 1),
  diveMode: DiveMode.oc,
  gradientFactorLow: gfLow,
  gradientFactorHigh: gfHigh,
  decoAlgorithm: decoAlgorithm,
  profile: _squareProfile(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  /// A container whose diver settings are the shipped defaults -- notably
  /// GF 50/85, the pair the reporter saw on a 45/80 computer.
  ProviderContainer defaultSettingsContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
        settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('diveProfileAnalysisProvider gradient factor provenance', () {
    test('reports the computer\'s gradient factors when the dive recorded '
        'them', () {
      final analysis = defaultSettingsContainer().read(
        diveProfileAnalysisProvider(_dive(gfLow: 45, gfHigh: 80)),
      );

      expect(analysis, isNotNull);
      expect(analysis!.gfSource!.low, 45);
      expect(analysis.gfSource!.high, 80);
      expect(analysis.gfSource!.origin, GfOrigin.computer);
    });

    test('marks the diver settings as the origin when the dive recorded no '
        'gradient factors', () {
      final analysis = defaultSettingsContainer().read(
        diveProfileAnalysisProvider(_dive()),
      );

      expect(analysis, isNotNull);
      // The shipped default, and the exact pair the reporter saw on a dive
      // from a 45/80 computer.
      expect(analysis!.gfSource!.low, 50);
      expect(analysis.gfSource!.high, 85);
      expect(analysis.gfSource!.origin, GfOrigin.diverSettings);
    });

    test('surfaces a recorded non-GF deco model alongside the fallback', () {
      // A Shearwater run in VPM records its model but no gradient factors.
      final analysis = defaultSettingsContainer().read(
        diveProfileAnalysisProvider(_dive(decoAlgorithm: 'vpm')),
      );

      expect(analysis, isNotNull);
      expect(analysis!.gfSource!.origin, GfOrigin.diverSettings);
      expect(analysis.gfSource!.recordedNonGfAlgorithm, isTrue);
      expect(analysis.gfSource!.recordedAlgorithm, 'vpm');
    });

    test('analyzes with the dive\'s gradient factors, not the settings', () {
      // Provenance must describe the numbers actually fed to the engine, so
      // the per-sample DecoStatus has to agree with the reported source.
      final analysis = defaultSettingsContainer().read(
        diveProfileAnalysisProvider(_dive(gfLow: 45, gfHigh: 80)),
      );

      expect(analysis!.decoStatuses, isNotEmpty);
      expect(analysis.decoStatuses.first.gfLow, closeTo(0.45, 1e-9));
      expect(analysis.decoStatuses.first.gfHigh, closeTo(0.80, 1e-9));
    });
  });
}
