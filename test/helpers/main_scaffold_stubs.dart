import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';

/// Stub that avoids the 5-second timer in the real [UpdateStatusNotifier].
class StubUpdateStatusNotifier extends StateNotifier<UpdateStatus>
    implements UpdateStatusNotifier {
  StubUpdateStatusNotifier() : super(const UpToDate());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub that avoids platform channel dependencies.
class StubDownloadNotifier extends StateNotifier<DownloadState>
    implements DownloadNotifier {
  StubDownloadNotifier() : super(const DownloadState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub settings notifier, so a shell test can set the toggles MainScaffold
/// reads without touching the database.
class StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  StubSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps [page] as the one route inside a real [MainScaffold] at [size], in
/// English, with the shell's providers stubbed and [overrides] added (provider
/// overrides, typed loosely so callers need no Riverpod internals).
Future<void> pumpMainScaffoldShell(
  WidgetTester tester, {
  required Size size,
  required Widget page,
  List<Object> overrides = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => page),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateServiceProvider.overrideWith((ref) async => null),
        updateStatusProvider.overrideWith((ref) => StubUpdateStatusNotifier()),
        downloadNotifierProvider.overrideWith((ref) => StubDownloadNotifier()),
        settingsProvider.overrideWith(
          (ref) => StubSettingsNotifier(const AppSettings()),
        ),
        ...overrides,
      ].cast(),
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
