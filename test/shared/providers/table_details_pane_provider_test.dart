import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

/// Mock SettingsNotifier that doesn't access the database
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _createContainer({_MockSettingsNotifier? notifier}) {
  return ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => notifier ?? _MockSettingsNotifier(),
      ),
    ],
  );
}

void main() {
  group('tableDetailsPaneProvider', () {
    test('defaults to false for unknown section', () {
      final container = _createContainer();
      addTearDown(container.dispose);
      final value = container.read(tableDetailsPaneProvider('unknown'));
      expect(value, isFalse);
    });

    test('defaults to persisted setting value', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(showDetailsPaneSites: true);
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(container.read(tableDetailsPaneProvider('sites')), isTrue);
      expect(container.read(tableDetailsPaneProvider('dives')), isFalse);
    });

    test('can be toggled to true', () {
      final container = _createContainer();
      addTearDown(container.dispose);
      container.read(tableDetailsPaneProvider('sites').notifier).state = true;
      expect(container.read(tableDetailsPaneProvider('sites')), isTrue);
    });

    test('sections are independent', () {
      final container = _createContainer();
      addTearDown(container.dispose);
      container.read(tableDetailsPaneProvider('sites').notifier).state = true;
      expect(container.read(tableDetailsPaneProvider('buddies')), isFalse);
    });

    test('can toggle from true back to false', () {
      final container = _createContainer();
      addTearDown(container.dispose);
      container.read(tableDetailsPaneProvider('sites').notifier).state = true;
      expect(container.read(tableDetailsPaneProvider('sites')), isTrue);
      container.read(tableDetailsPaneProvider('sites').notifier).state = false;
      expect(container.read(tableDetailsPaneProvider('sites')), isFalse);
    });

    test('reads persisted dives setting', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(showDetailsPaneDives: true);
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(container.read(tableDetailsPaneProvider('dives')), isTrue);
    });

    test('reads persisted buddies setting', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(showDetailsPaneBuddies: true);
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(container.read(tableDetailsPaneProvider('buddies')), isTrue);
    });

    test('reads persisted trips setting', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(showDetailsPaneTrips: true);
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(container.read(tableDetailsPaneProvider('trips')), isTrue);
    });

    test('reads persisted equipment setting', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(showDetailsPaneEquipment: true);
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(container.read(tableDetailsPaneProvider('equipment')), isTrue);
    });

    test('reads persisted diveCenters setting', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(showDetailsPaneDiveCenters: true);
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(container.read(tableDetailsPaneProvider('diveCenters')), isTrue);
    });

    test('reads persisted certifications setting', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(
        showDetailsPaneCertifications: true,
      );
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(
        container.read(tableDetailsPaneProvider('certifications')),
        isTrue,
      );
    });

    test('reads persisted courses setting', () {
      final mockNotifier = _MockSettingsNotifier();
      mockNotifier.state = const AppSettings(showDetailsPaneCourses: true);
      final container = _createContainer(notifier: mockNotifier);
      addTearDown(container.dispose);
      expect(container.read(tableDetailsPaneProvider('courses')), isTrue);
    });
  });
}
