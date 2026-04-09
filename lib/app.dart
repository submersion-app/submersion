import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_menu_channel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/shared/services/file_share_handler.dart';
import 'package:submersion/shared/services/incoming_file_handler.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

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
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final FileShareHandler _fileShareHandler;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleListener = AppLifecycleListener(onExitRequested: _closeDatabases);
    registerUpdateMenuChannel(ref);
    _fileShareHandler = FileShareHandler(
      onFileReceived: _handleIncomingFile,
      onError: (_) {
        final l10n = _scaffoldMessengerKey.currentContext != null
            ? AppLocalizations.of(_scaffoldMessengerKey.currentContext!)
            : null;
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              l10n?.dropTarget_error_readFailed ?? 'Could not read file',
            ),
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeSyncOnLaunch();
      _fileShareHandler.initialize();
    });
  }

  @override
  void dispose() {
    _fileShareHandler.dispose();
    _lifecycleListener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Close databases before the app exits. Uses onExitRequested (mapped from
  /// NSApplicationDelegate.applicationShouldTerminate: on macOS) which is
  /// async and fires before the Dart VM begins isolate/FFI teardown. Without
  /// this, the Drift background isolate can outlive the FFI subsystem and
  /// crash in sqlite3_close_v2 → functionDestroy.
  Future<AppExitResponse> _closeDatabases() async {
    await Future.wait([
      DatabaseService.instance.close(),
      LocalCacheDatabaseService.instance.close(),
    ]);
    return AppExitResponse.exit;
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

  Future<void> _handleIncomingFile(Uint8List bytes, String fileName) async {
    final router = ref.read(appRouterProvider);
    final location = router.routeInformationProvider.value.uri.path;

    final l10n = _scaffoldMessengerKey.currentContext != null
        ? AppLocalizations.of(_scaffoldMessengerKey.currentContext!)
        : null;

    final shouldNavigate = await handleIncomingFile(
      bytes: bytes,
      fileName: fileName,
      currentPath: location,
      notifier: ref.read(universalImportNotifierProvider.notifier),
      messenger: _scaffoldMessengerKey.currentState,
      wizardActiveMessage: l10n?.dropTarget_error_wizardActive,
      unsupportedFileMessage: l10n?.dropTarget_error_unsupportedFile,
    );

    if (shouldNavigate) {
      router.go('/transfer/import-wizard');
    }
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
      scaffoldMessengerKey: _scaffoldMessengerKey,
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
