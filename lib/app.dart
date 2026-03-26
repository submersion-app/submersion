import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_menu_channel.dart';

const Locale _defaultFallbackLocale = Locale('en');
const Set<String> _invalidSystemLocaleLanguageCodes = {'c', 'posix'};

Locale resolveAppLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales, {
  Locale fallbackLocale = _defaultFallbackLocale,
}) {
  // Some Linux environments report generic locales like C.UTF-8/POSIX, which
  // Flutter can't match to our translations. Without this guard, Flutter falls
  // back to the first supported locale, which can accidentally select an RTL UI.
  final sanitizedLocales = preferredLocales
      ?.where((locale) => _isUsableSystemLocale(locale))
      .toList();

  if (sanitizedLocales == null || sanitizedLocales.isEmpty) {
    return fallbackLocale;
  }

  final hasSupportedLanguage = sanitizedLocales.any(
    (preferredLocale) => supportedLocales.any(
      (supportedLocale) =>
          supportedLocale.languageCode == preferredLocale.languageCode,
    ),
  );

  if (!hasSupportedLanguage) {
    return fallbackLocale;
  }

  return basicLocaleListResolution(sanitizedLocales, supportedLocales);
}

bool _isUsableSystemLocale(Locale locale) {
  final languageCode = locale.languageCode.trim().toLowerCase();
  return languageCode.isNotEmpty &&
      !_invalidSystemLocaleLanguageCodes.contains(languageCode);
}

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
    registerUpdateMenuChannel(ref);
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
    final themePreset = ref.watch(themePresetProvider);
    final localeSetting = ref.watch(localeProvider);

    // Restore the last used cloud sync provider on app startup
    ref.watch(restoreLastProviderProvider);

    return MaterialApp.router(
      title: 'Submersion',
      debugShowCheckedModeBanner: false,
      theme: AppThemeRegistry.resolveTheme(themePreset, Brightness.light),
      darkTheme: AppThemeRegistry.resolveTheme(themePreset, Brightness.dark),
      themeMode: themeMode,
      locale: _resolveLocale(localeSetting),
      localeListResolutionCallback: (preferredLocales, supportedLocales) {
        return resolveAppLocale(preferredLocales, supportedLocales);
      },
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
