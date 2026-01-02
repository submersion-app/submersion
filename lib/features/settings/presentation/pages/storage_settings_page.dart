import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/storage_config.dart';
import '../../../../core/services/database_migration_service.dart';
import '../providers/storage_providers.dart';
import '../widgets/existing_database_dialog.dart';
import '../widgets/migration_confirmation_dialog.dart';
import '../widgets/migration_progress_dialog.dart';

class StorageSettingsPage extends ConsumerStatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  ConsumerState<StorageSettingsPage> createState() =>
      _StorageSettingsPageState();
}

class _StorageSettingsPageState extends ConsumerState<StorageSettingsPage> {
  ExistingDatabaseInfo? _currentDbInfo;
  bool _isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentDatabaseInfo();
  }

  Future<void> _loadCurrentDatabaseInfo() async {
    setState(() => _isLoadingInfo = true);
    try {
      final migrationService = ref.read(databaseMigrationServiceProvider);
      final info = await migrationService.getCurrentDatabaseInfo();
      if (mounted) {
        setState(() {
          _currentDbInfo = info;
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInfo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageState = ref.watch(storageConfigNotifierProvider);
    final platformCaps = ref.watch(storagePlatformCapabilitiesProvider);
    final currentPathAsync = ref.watch(currentDatabasePathProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Storage'),
      ),
      body: storageState.isMigrating
          ? const _MigrationInProgressView()
          : ListView(
              children: [
                // Current location card
                _buildCurrentLocationCard(
                  context,
                  theme,
                  currentPathAsync,
                  storageState,
                ),
                const Divider(),

                // Storage location options
                _buildSectionHeader(context, 'Storage Location'),

                // App Default option
                _buildStorageOption(
                  context,
                  theme,
                  title: 'App Default',
                  subtitle: 'Standard app storage location',
                  icon: Icons.phone_android,
                  isSelected:
                      storageState.config.mode == StorageLocationMode.appDefault,
                  onTap: () => _handleSelectAppDefault(storageState),
                ),

                // Custom Folder option
                if (platformCaps.supportsCustomFolder)
                  _buildStorageOption(
                    context,
                    theme,
                    title: 'Custom Folder',
                    subtitle: storageState.config.mode ==
                            StorageLocationMode.customFolder
                        ? _truncatePath(storageState.config.customFolderPath)
                        : 'Choose a synced folder (Dropbox, Google Drive, etc.)',
                    icon: Icons.folder,
                    isSelected: storageState.config.mode ==
                        StorageLocationMode.customFolder,
                    onTap: () => _handleSelectCustomFolder(storageState),
                    trailing: storageState.config.mode ==
                            StorageLocationMode.customFolder
                        ? TextButton(
                            onPressed: () =>
                                _handleChangeCustomFolder(storageState),
                            child: const Text('Change'),
                          )
                        : null,
                  ),

                const SizedBox(height: 16),

                // Info banner about cloud sync
                _buildInfoBanner(context, theme, storageState),

                // Error display
                if (storageState.error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorBanner(context, theme, storageState.error!),
                ],

                // Success display
                if (storageState.lastMigrationResult?.success == true) ...[
                  const SizedBox(height: 16),
                  _buildSuccessBanner(
                    context,
                    theme,
                    storageState.lastMigrationResult!,
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildCurrentLocationCard(
    BuildContext context,
    ThemeData theme,
    AsyncValue<String> currentPathAsync,
    StorageConfigState storageState,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  storageState.config.mode == StorageLocationMode.customFolder
                      ? Icons.folder
                      : Icons.storage,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Current Location',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            currentPathAsync.when(
              data: (path) => Text(
                path,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              loading: () => const Text('Loading...'),
              error: (e, _) => Text('Error: $e'),
            ),
            if (_currentDbInfo != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_currentDbInfo!.formattedFileSize} • '
                '${_currentDbInfo!.diveCount} dives • '
                '${_currentDbInfo!.siteCount} sites',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (_isLoadingInfo) ...[
              const SizedBox(height: 8),
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStorageOption(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ??
          (isSelected
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : const Icon(Icons.chevron_right)),
      selected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildInfoBanner(
    BuildContext context,
    ThemeData theme,
    StorageConfigState storageState,
  ) {
    final isCustomFolder =
        storageState.config.mode == StorageLocationMode.customFolder;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCustomFolder
                  ? 'App-managed cloud sync is disabled. Your folder\'s sync service (Dropbox, Google Drive, etc.) handles synchronization.'
                  : 'Using a custom folder disables app-managed cloud sync. Your folder\'s sync service will handle synchronization instead.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    ThemeData theme,
    String error,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(storageConfigNotifierProvider.notifier).clearError();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(
    BuildContext context,
    ThemeData theme,
    MigrationResult result,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Database moved successfully',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                if (result.backupPath != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Original kept as backup at:\n${result.backupPath}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref
                  .read(storageConfigNotifierProvider.notifier)
                  .clearMigrationResult();
            },
          ),
        ],
      ),
    );
  }

  String _truncatePath(String? path) {
    if (path == null) return 'Not set';
    if (path.length <= 40) return path;

    // Show last 40 characters with ellipsis
    return '...${path.substring(path.length - 37)}';
  }

  Future<void> _handleSelectAppDefault(StorageConfigState currentState) async {
    if (currentState.config.mode == StorageLocationMode.appDefault) {
      return; // Already selected
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => MigrationConfirmationDialog(
        fromPath: currentState.config.customFolderPath ?? 'Custom folder',
        toPath: 'App default location',
        isMovingToCustom: false,
      ),
    );

    if (confirmed == true && mounted) {
      await _performMigrationToDefault();
    }
  }

  Future<void> _handleSelectCustomFolder(
    StorageConfigState currentState,
  ) async {
    if (currentState.config.mode == StorageLocationMode.customFolder) {
      return; // Already selected
    }

    await _selectAndMigrateToCustomFolder();
  }

  Future<void> _handleChangeCustomFolder(
    StorageConfigState currentState,
  ) async {
    await _selectAndMigrateToCustomFolder();
  }

  Future<void> _selectAndMigrateToCustomFolder() async {
    // Pick a folder
    final notifier = ref.read(storageConfigNotifierProvider.notifier);
    final pickResult = await notifier.pickCustomFolder();

    if (pickResult == null || !mounted) return;

    // Extract path from the result
    final folderPath = pickResult.path;

    // Check for existing database
    final existingDb = await notifier.checkForExistingDatabase(folderPath);

    if (existingDb != null && mounted) {
      // Show existing database dialog
      final choice = await showDialog<ExistingDatabaseChoice>(
        context: context,
        builder: (context) => ExistingDatabaseDialog(
          existingInfo: existingDb,
          currentInfo: _currentDbInfo,
        ),
      );

      if (choice == null || !mounted) return;

      switch (choice) {
        case ExistingDatabaseChoice.useExisting:
          await _performSwitchToExisting(folderPath);
          break;
        case ExistingDatabaseChoice.replace:
          await _performReplaceExisting(folderPath);
          break;
      }
    } else if (mounted) {
      // No existing database, show migration confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => MigrationConfirmationDialog(
          fromPath: 'Current location',
          toPath: folderPath,
          isMovingToCustom: true,
        ),
      );

      if (confirmed == true && mounted) {
        await _performMigrationToCustom(folderPath);
      }
    }
  }

  Future<void> _performMigrationToDefault() async {
    // Show progress dialog
    _showProgressDialog('Moving to app default...');

    final notifier = ref.read(storageConfigNotifierProvider.notifier);
    final result = await notifier.migrateToDefault();

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog

      if (result.success) {
        // Allow UI to settle before invalidating providers
        // This prevents a deadlock from cascading provider rebuilds
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          ref.invalidate(storageConfigProvider);
          ref.invalidate(currentDatabasePathProvider);
          await _loadCurrentDatabaseInfo();
        }
      }
    }
  }

  Future<void> _performMigrationToCustom(String folderPath) async {
    _showProgressDialog('Moving database...');

    final notifier = ref.read(storageConfigNotifierProvider.notifier);
    final result = await notifier.migrateToCustomFolder(folderPath);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog

      if (result.success) {
        // Allow UI to settle before invalidating providers
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          ref.invalidate(storageConfigProvider);
          ref.invalidate(currentDatabasePathProvider);
          await _loadCurrentDatabaseInfo();
        }
      }
    }
  }

  Future<void> _performSwitchToExisting(String folderPath) async {
    _showProgressDialog('Switching to existing database...');

    final notifier = ref.read(storageConfigNotifierProvider.notifier);
    final result = await notifier.switchToExistingDatabase(folderPath);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog

      if (result.success) {
        // Allow UI to settle before invalidating providers
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          ref.invalidate(storageConfigProvider);
          ref.invalidate(currentDatabasePathProvider);
          await _loadCurrentDatabaseInfo();
        }
      }
    }
  }

  Future<void> _performReplaceExisting(String folderPath) async {
    _showProgressDialog('Replacing existing database...');

    final notifier = ref.read(storageConfigNotifierProvider.notifier);
    final result = await notifier.replaceExistingDatabase(folderPath);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog

      if (result.success) {
        // Allow UI to settle before invalidating providers
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          ref.invalidate(storageConfigProvider);
          ref.invalidate(currentDatabasePathProvider);
          await _loadCurrentDatabaseInfo();
        }
      }
    }
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => MigrationProgressDialog(message: message),
    );
  }
}

class _MigrationInProgressView extends StatelessWidget {
  const _MigrationInProgressView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Moving database...'),
          SizedBox(height: 8),
          Text(
            'Please do not close the app',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
