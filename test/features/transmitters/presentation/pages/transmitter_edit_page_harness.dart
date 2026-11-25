// The transmitter key editor's test harness (issue #4527, phase 4): not a
// test file of its own.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_page.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';

/// A stand-in for the item page: it pushes the editor once as it starts,
/// as the Transmitter card does, and keeps what each push came back with.
class _ItemPage extends StatefulWidget {
  const _ItemPage({required this.results});

  final List<Object?> results;

  @override
  State<_ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<_ItemPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await context.push<Object?>('/edit');
      widget.results.add(result);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('LIST'));
}

/// The key editor for Transmitter item [equipmentId], pushed over a
/// stand-in item page on a route with the app's leave check. What the
/// editor pops with lands in [results]. The validated diver follows
/// [diverIdNotifier], so a test can switch diver.
Widget buildTransmitterPage(
  MockCurrentDiverIdNotifier diverIdNotifier,
  SharedPreferences prefs, {
  String equipmentId = 'tx-gear',
  String? transmitterId,
  MockSettingsNotifier? settings,
  TransmitterRepository? repository,
  List<Object?>? results,
  List<Object> overrides = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => _ItemPage(results: results ?? []),
        routes: [
          GoRoute(
            path: 'edit',
            onExit: confirmLeaveRecordSitting,
            builder: (context, state) => TransmitterEditPage(
              equipmentId: equipmentId,
              transmitterId: transmitterId,
            ),
          ),
        ],
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
      validatedCurrentDiverIdProvider.overrideWith(
        (ref) async => ref.watch(currentDiverIdProvider),
      ),
      if (repository != null)
        transmitterRepositoryProvider.overrideWithValue(repository),
      ...overrides,
    ].cast(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    ),
  );
}

/// Pumps [page] on a surface tall enough that every field stays onstage
/// (the form carries helper text and per-field explanations, issue #3367).
Future<void> pumpTransmitterPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(page);
  await tester.pumpAndSettle();
}
