import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Widget _buildPage(
  MockCurrentDiverIdNotifier diverIdNotifier,
  SharedPreferences prefs, {
  String? transmitterId,
  String? initialSerial,
  MockSettingsNotifier? settings,
}) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('LIST')),
      ),
      GoRoute(
        path: '/edit',
        builder: (context, state) => TransmitterEditPage(
          transmitterId: transmitterId,
          initialSerial: initialSerial,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith(
        (ref) => settings ?? MockSettingsNotifier(),
      ),
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ].cast(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });
  tearDown(tearDownTestDatabase);

  testWidgets('prefills the serial and saves a new entry for the diver', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '555'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('transmitter_label')), 'Stage');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.enterText(
      find.byKey(const Key('transmitter_working_pressure')),
      '207',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await TransmitterRepository().getForDiver('diver-1');
    expect(saved.single.transmitterSerial, '555');
    expect(saved.single.label, 'Stage');
    expect(saved.single.volumeL, closeTo(11.1, 0.01));
    expect(saved.single.workingPressureBar, 207);
    expect(find.text('LIST'), findsOneWidget);
    // Saved from an Assign flow: the snackbar offers the retroactive apply.
    expect(find.text('Apply to existing dives'), findsOneWidget);
  });

  testWidgets('refuses an entry with neither serial nor channel', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'T1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Enter a transmitter serial, or pick a dive computer and channel',
      ),
      findsOneWidget,
    );
    expect(await TransmitterRepository().getForDiver('diver-1'), isEmpty);
  });

  testWidgets('refuses a duplicate serial naming the existing entry', (
    tester,
  ) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Stage',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(
      _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'Other');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Already assigned to Stage'), findsOneWidget);
  });

  testWidgets('shows volume in cubic feet and stores liters', (tester) async {
    final settings = MockSettingsNotifier();
    await settings.setVolumeUnit(VolumeUnit.cubicFeet);
    await settings.setPressureUnit(PressureUnit.psi);
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'AL80',
        volumeL: 11.1,
        workingPressureBar: 207,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );

    await tester.pumpWidget(
      _buildPage(
        diverIdNotifier,
        prefs,
        transmitterId: 'e1',
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();

    // 11.1 L at 207 bar is 81.1 cuft; 207 bar is 3002 psi.
    expect(find.widgetWithText(TextFormField, '81.1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '3002'), findsOneWidget);
  });
}
