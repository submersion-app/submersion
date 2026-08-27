import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/app/app_exit.dart';
import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/presentation/widgets/lock_barrier.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/core/theme/display_zoom_shortcuts.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_menu_channel.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_menu_channel.dart';
import 'package:submersion/features/backup/presentation/pages/restore_complete_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_barrier.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/shared/services/file_share_handler.dart';
import 'package:submersion/shared/services/incoming_file_handler.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';

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
  bool _adoptDialogShownThisSession = false;
  late final FileShareHandler _fileShareHandler;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleListener = AppLifecycleListener(onExitRequested: _closeDatabases);
    registerUpdateMenuChannel(ref);
    registerDisplayZoomMenuChannel(ref);
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
      _resumeMediaTransfers();
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
  /// crash in sqlite3_close_v2 -> functionDestroy ("GetFfiCallbackMetadata
  /// called after shutdown"), which stalls the quit.
  ///
  /// The guarantees that make this safe to be the platform's only reply path
  /// (always answers, never throws, never exceeds its budget) live in
  /// [closeDatabasesForExit]; see its doc for why totality matters here and
  /// what happens natively when the reply never arrives.
  Future<AppExitResponse> _closeDatabases() => closeDatabasesForExit(
    closeMain: () => DatabaseService.instance.close(),
    closeCache: () => LocalCacheDatabaseService.instance.close(),
    onError: (error, stack) => LoggerService.forClass(SubmersionApp).warning(
      'Database close during app exit did not finish cleanly',
      error: error,
      stackTrace: stack,
    ),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref.read(appLockNotifierProvider.notifier).noteBackgrounded();
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(appLockNotifierProvider.notifier).noteResumed();
      _maybeSyncOnResume();
      _resumeMediaTransfers();
    }
  }

  /// Restarts an outstanding media transfer queue (issue #1270).
  ///
  /// On launch and on every resume, because the queue's own triggers all live
  /// downstream of a runtime this process may never have built: a desktop app
  /// sits in one process for days, and a queue that stopped mid-import stayed
  /// stopped through every restart. The provider does the deciding - it
  /// short-circuits on an unattached device or an empty queue before anything
  /// expensive - and contains its own failures, which is what makes this call
  /// safe to leave unawaited.
  ///
  /// Safe to reach the local cache database from here: StartupWrapper mounts
  /// SubmersionRestart (and so this widget) only once `_state` is ready, which
  /// it sets after `_initializeServices()` returns - and that awaits
  /// `LocalCacheDatabaseService.instance.initialize`. This runs a post-frame
  /// callback later still.
  void _resumeMediaTransfers() {
    unawaited(ref.read(mediaTransferResumeProvider)());
  }

  Future<void> _maybeSyncOnLaunch() async {
    final settings = ref.read(syncBehaviorProvider);
    if (!settings.autoSyncEnabled || !settings.syncOnLaunch) return;
    // Wait for the launch reconcile (watched in build) to finish before the
    // first sync reads sync state. A restore-triggered rebaseline may still be
    // in flight; syncing mid-rebaseline would read a rewound lastSync/tombstone
    // set and defeat the "rebaseline before anything reads sync state"
    // guarantee. Reconcile is launch-safe (resolves with a status, never
    // throws), but guard anyway so a failure can't block launch sync forever.
    try {
      await ref.read(reconcileDeviceIdentityProvider.future);
    } catch (_) {
      // Already logged inside reconcileDeviceIdentity; proceed with the sync.
    }
    if (!mounted) return;
    ref.read(syncStateProvider.notifier).performSync(auto: true);
  }

  void _maybeSyncOnResume() {
    final settings = ref.read(syncBehaviorProvider);
    if (!settings.autoSyncEnabled || !settings.syncOnResume) return;
    ref.read(syncStateProvider.notifier).performSync(auto: true);
  }

  void _onSyncStateChanged(SyncState? prev, SyncState next) {
    final ctx = _scaffoldMessengerKey.currentContext;
    final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
    final messenger = _scaffoldMessengerKey.currentState;

    // Post-restore merge notice (start).
    if (next.postRestoreSyncing && !(prev?.postRestoreSyncing ?? false)) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.settings_cloudSync_postRestore_syncing ??
                'Syncing your restored library with the cloud…',
          ),
        ),
      );
    }
    // Post-restore merge notice (done).
    if ((prev?.postRestoreSyncing ?? false) &&
        !next.postRestoreSyncing &&
        (next.status == SyncStatus.success ||
            next.status == SyncStatus.hasConflicts)) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.settings_cloudSync_postRestore_synced ??
                'Restored library synced.',
          ),
        ),
      );
    }
    // Replaced-library adopt: persistent banner + once-per-session modal.
    if (next.replaceAwaitingAdoption &&
        !(prev?.replaceAwaitingAdoption ?? false)) {
      _surfaceReplaceAdoption(next.replaceMarker);
    }
    if (!next.replaceAwaitingAdoption &&
        (prev?.replaceAwaitingAdoption ?? false)) {
      messenger?.clearMaterialBanners();
    }
  }

  void _surfaceReplaceAdoption(LibraryEpochMarker? marker) {
    if (marker == null) return;
    final ctx = _scaffoldMessengerKey.currentContext;
    final l10n = ctx != null ? AppLocalizations.of(ctx) : null;
    final messenger = _scaffoldMessengerKey.currentState;

    // Persistent banner: rides across every screen until adopted.
    messenger?.clearMaterialBanners();
    messenger?.showMaterialBanner(
      MaterialBanner(
        content: Text(
          l10n?.settings_cloudSync_replace_globalBanner(marker.displayName) ??
              'Sync is paused — the library was replaced from a backup.',
        ),
        leading: const Icon(Icons.restore_page_outlined),
        actions: [
          TextButton(
            onPressed: () => _openAdoptDialog(marker),
            child: Text(
              l10n?.settings_cloudSync_replace_reviewAction ?? 'Review',
            ),
          ),
        ],
      ),
    );

    // Modal once per session; the banner persists if it is dismissed.
    if (!_adoptDialogShownThisSession) {
      _adoptDialogShownThisSession = true;
      _openAdoptDialog(marker);
    }
  }

  void _openAdoptDialog(LibraryEpochMarker marker) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null) return;
      showAdoptReplacedLibraryDialog(navContext, ref, marker);
    });
  }

  void _onBackupOperationChanged(
    BackupOperationState? prev,
    BackupOperationState next,
  ) {
    // Fire once, on the transition into restoreComplete.
    if (next.status != BackupOperationStatus.restoreComplete) return;
    if (prev?.status == BackupOperationStatus.restoreComplete) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null) return;
      RestoreCompletePage.show(navContext);
    });
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
      // PUSH (not go): the wizard is a sub-page, so system back returns to
      // wherever the drop happened instead of closing the app (#647).
      router.push('/transfer/import-wizard');
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

    // Detect a database restore and re-baseline sync before anything reads
    // sync state, so a rewound baseline can't stall sync or resurrect deletes.
    ref.watch(reconcileDeviceIdentityProvider);

    // Restore the last used cloud sync provider BEFORE listening to sync state:
    // listening instantiates SyncNotifier, whose _initialize needs the restored
    // provider to run the post-restore intent / replaced-library surfacing.
    ref.watch(restoreLastProviderProvider);

    // Turn transient sync state into unmissable, screen-independent UI: the
    // post-restore "syncing" notice, and the replaced-library adopt prompt.
    ref.listen<SyncState>(syncStateProvider, _onSyncStateChanged);

    // App-level restore completion: hand off to RestoreCompletePage from here
    // rather than from whichever page triggered the restore. That page may be
    // disposed (the user navigated away) by the time the restore finishes, in
    // which case its own listener would never fire and the app would be
    // stranded on a stale screen. Listening at the app root guarantees the
    // hand-off -- and its restartApp() -- always happens.
    ref.listen<BackupOperationState>(
      backupOperationProvider,
      _onBackupOperationChanged,
    );

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
        // Block all interaction while a database restore runs, so no data page
        // can rebuild against the transient null database mid-restore. Kept
        // outside the zoom scope so the barrier stays a full-screen, unscaled
        // overlay. LockBarrier sits OUTSIDE RestoreBarrier so the App Lock
        // re-lock overlay covers restore UI too.
        return LockBarrier(
          child: RestoreBarrier(
            child: Consumer(
              builder: (context, ref, _) {
                // Watched here rather than in build() so dragging the zoom
                // slider rebuilds only this subtree, not all of MaterialApp.
                final zoom = ref.watch(displayZoomNotifierProvider);
                final notifier = ref.read(displayZoomNotifierProvider.notifier);
                final useMeta =
                    defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.iOS;

                return CallbackShortcuts(
                  bindings: displayZoomShortcuts(
                    onZoomIn: () => notifier.stepBy(1),
                    onZoomOut: () => notifier.stepBy(-1),
                    onReset: notifier.reset,
                    useMetaModifier: useMeta,
                  ),
                  // CallbackShortcuts only fires for keystrokes inside its
                  // focused subtree, and nothing has focus on desktop
                  // cold-start, so the shortcuts would otherwise be dead until
                  // the user clicks something.
                  child: Focus(
                    autofocus: true,
                    child: DisplayZoomScope(zoom: zoom, child: child!),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
