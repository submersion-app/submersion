import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/domain/entities/migration_progress.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/main.dart' show SubmersionRestart;

enum _StartupState { initializing, migrating, ready, error }

class StartupWrapper extends StatefulWidget {
  final SharedPreferences prefs;
  final LogFileService logFileService;
  final DatabaseLocationService locationService;

  const StartupWrapper({
    super.key,
    required this.prefs,
    required this.logFileService,
    required this.locationService,
  });

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper> {
  _StartupState _state = _StartupState.initializing;
  MigrationProgress _progress = const MigrationProgress(
    currentStep: 0,
    totalSteps: 0,
  );
  String _errorMessage = '';
  bool _isVersionMismatch = false;
  int _dbVersion = 0;
  int _appVersion = 0;

  @override
  void initState() {
    super.initState();
    _runInitialization();
  }

  Future<void> _runInitialization() async {
    try {
      // Determine if migration is needed before opening the database
      final dbPath = await widget.locationService.getDatabasePath();
      final storedVersion = DatabaseService.getStoredSchemaVersion(dbPath);
      final needsMigration =
          storedVersion != null &&
          storedVersion > 0 &&
          storedVersion < AppDatabase.currentSchemaVersion;

      final totalSteps = needsMigration
          ? AppDatabase.migrationStepCount(storedVersion)
          : 0;

      if (needsMigration && mounted) {
        setState(() {
          _state = _StartupState.migrating;
          _progress = MigrationProgress(currentStep: 0, totalSteps: totalSteps);
        });
      }

      // Run DB init and minimum splash duration in parallel
      await Future.wait([
        _initializeServices(),
        Future.delayed(const Duration(seconds: 1)),
      ]);

      if (mounted) {
        setState(() => _state = _StartupState.ready);
      }
    } on DatabaseVersionMismatchException catch (e) {
      if (mounted) {
        setState(() {
          _state = _StartupState.error;
          _isVersionMismatch = true;
          _dbVersion = e.databaseVersion;
          _appVersion = e.appVersion;
        });
      }
    } catch (e) {
      debugPrint('FATAL: App initialization failed: $e');
      if (mounted) {
        setState(() {
          _state = _StartupState.error;
          _errorMessage = '$e';
        });
      }
    }
  }

  Future<void> _initializeServices() async {
    await DatabaseService.instance.initialize(
      locationService: widget.locationService,
      onMigrationProgress: (currentStep, totalSteps) {
        if (mounted) {
          setState(() {
            _progress = MigrationProgress(
              currentStep: currentStep,
              totalSteps: totalSteps,
            );
          });
        }
      },
    );

    await LocalCacheDatabaseService.instance.initialize();
    await NotificationService.instance.initialize();
    await initializeBackgroundService();

    try {
      await TileCacheService.instance.initialize();
    } catch (e) {
      debugPrint('Warning: Tile cache initialization failed: $e');
    }

    final speciesRepository = SpeciesRepository();
    await speciesRepository.seedBuiltInSpecies();
  }

  void _closeApp() {
    if (Platform.isIOS || Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    // Return SubmersionRestart directly when ready to avoid nesting
    // MaterialApp inside MaterialApp (SubmersionRestart contains its own
    // MaterialApp.router via SubmersionApp).
    if (_state == _StartupState.ready) {
      return SubmersionRestart(
        prefs: widget.prefs,
        logFileService: widget.logFileService,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _state == _StartupState.error
          ? Scaffold(
              key: const ValueKey('error'),
              backgroundColor: backgroundColor,
              body: SafeArea(
                child: Center(
                  child: _buildErrorContent(textColor, subtitleColor),
                ),
              ),
            )
          : Scaffold(
              // Use 'splash' key for both initializing and migrating so
              // AnimatedSize handles the progress bar transition instead of
              // AnimatedSwitcher triggering a full Scaffold crossfade.
              key: const ValueKey('splash'),
              body: OceanBackground(
                child: SafeArea(
                  child: Center(child: _buildSplashContent(isDark)),
                ),
              ),
            ),
    );
  }

  Widget _buildSplashContent(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/icon/icon.png', width: 120, height: 120),
          ),
          const SizedBox(height: 24),
          const Text(
            'Submersion',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 240,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _state == _StartupState.migrating
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: _progress.fraction,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Upgrading database... '
                          'step ${_progress.currentStep} of ${_progress.totalSteps}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(Color textColor, Color subtitleColor) {
    if (_isVersionMismatch) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.update, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              'Update Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your dive data was saved by a newer version of '
              'Submersion (schema v$_dbVersion). This version '
              'only supports up to schema v$_appVersion.',
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please update Submersion to the latest version. '
              'Your data is safe and has not been modified.',
              style: TextStyle(fontSize: 14, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _closeApp, child: const Text('Close')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 24),
          Text(
            'Database upgrade failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Try restarting the app. If this persists, '
            'reinstall or contact support.',
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _closeApp, child: const Text('Close')),
        ],
      ),
    );
  }
}
