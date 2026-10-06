import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_handoff_card.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/suunto_json_handoff_card.dart';

/// Step 0: File selection with drag-and-drop area and file picker button.
class FileSelectionStep extends ConsumerWidget {
  const FileSelectionStep({super.key});

  static bool get _isDesktop {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);

    final hasFile = state.files.isNotEmpty;
    // Only offer the Garmin option when a device is actually mounted, so the
    // import dialog stays clean for everyone who doesn't own one.
    final hasGarminDevice =
        ref.watch(garminDevicesProvider).valueOrNull?.isNotEmpty ?? false;

    // A hand-off format never advances to Confirm Source: a Seacraft ENC
    // file is a route, not a dive log, and a Suunto JSON export belongs to
    // the Suunto importer (#1445). This step shows that flow's card instead.
    final format = state.detectionResult?.format;
    final handoffBytes = format != null && format.isHandoff
        ? state.fileBytes
        : null;
    if (handoffBytes != null) {
      final fileName = state.fileName ?? '';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: format == ImportFormat.suuntoJson
            ? SuuntoJsonHandoffCard(bytes: handoffBytes, fileName: fileName)
            : NavTrackHandoffCard(bytes: handoffBytes, fileName: fileName),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(
                state.isLoading
                    ? context.l10n.universalImport_label_detecting
                    : hasFile
                    ? context.l10n.universalImport_action_changeFile
                    : context.l10n.universalImport_action_selectFiles,
              ),
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(universalImportNotifierProvider.notifier)
                        .pickFiles(),
            ),
          ),
          if (_isDesktop) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: Text(context.l10n.universalImport_action_chooseFolder),
                onPressed: state.isLoading
                    ? null
                    : () => ref
                          .read(universalImportNotifierProvider.notifier)
                          .pickFolder(),
              ),
            ),
            if (hasGarminDevice) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.watch),
                  label: Text(
                    context.l10n.universalImport_action_importFromGarmin,
                  ),
                  onPressed: state.isLoading
                      ? null
                      : () => ref
                            .read(universalImportNotifierProvider.notifier)
                            .importFromGarminDevice(),
                ),
              ),
            ],
          ],
          if (state.error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: state.error!),
          ],
          if (hasFile) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.isBatch
                            ? context.l10n.universalImport_label_filesSelected(
                                state.selectedFileCount,
                              )
                            : state.fileName ?? '',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          ExcludeSemantics(
            child: Icon(
              Icons.upload_file,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.universalImport_title,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.universalImport_description_supportedFormats,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
