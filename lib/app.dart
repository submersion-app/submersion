import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/theme/app_theme.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

class SubmersionApp extends ConsumerStatefulWidget {
  const SubmersionApp({super.key});

  @override
  ConsumerState<SubmersionApp> createState() => _SubmersionAppState();
}

class _SubmersionAppState extends ConsumerState<SubmersionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeSyncOnLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeSyncOnResume();
    }
  }

  void _maybeSyncOnLaunch() {
    final settings = ref.read(syncBehaviorProvider);
    if (!settings.autoSyncEnabled || !settings.syncOnLaunch) return;
    ref.read(syncStateProvider.notifier).performSync();
  }

  void _maybeSyncOnResume() {
    final settings = ref.read(syncBehaviorProvider);
    if (!settings.autoSyncEnabled || !settings.syncOnResume) return;
    ref.read(syncStateProvider.notifier).performSync();
  }

  Locale? _resolveLocale(String localeSetting) {
    if (localeSetting == 'system') return null;
    return Locale(localeSetting);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localeSetting = ref.watch(localeProvider);

    // Restore the last used cloud sync provider on app startup
    ref.watch(restoreLastProviderProvider);

    return MaterialApp.router(
      title: 'Submersion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: _resolveLocale(localeSetting),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return child!;
      },
    );
  }
}
