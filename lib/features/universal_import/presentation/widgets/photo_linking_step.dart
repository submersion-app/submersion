import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Wizard step shown when the parsed payload carries photo references.
///
/// Lets the user pick a root folder so [PhotoResolver] can locate each
/// photo on the local filesystem, or skip photo linking entirely.
///
/// Desktop only: iOS/Android show a "this is a desktop feature" message
/// with a single "Continue without photos" action that calls
/// [UniversalImportNotifier.skipPhotoLinking].
class PhotoLinkingStep extends ConsumerWidget {
  const PhotoLinkingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final notifier = ref.read(universalImportNotifierProvider.notifier);
    final theme = Theme.of(context);

    final refs = state.payload?.imageRefs ?? const [];

    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${refs.length} photo references found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            _MobileBranch(notifier: notifier)
          else
            _DesktopBranch(state: state, notifier: notifier),
        ],
      ),
    );
  }
}

/// Mobile (iOS / Android) branch: photo linking needs filesystem access
/// we can't reliably offer on mobile, so we just explain and offer to
/// continue without photos.
class _MobileBranch extends StatelessWidget {
  const _MobileBranch({required this.notifier});

  final UniversalImportNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo import is not available on this platform. Run the import '
          'from a desktop device and photos will be attached to the dives. '
          'Tap "Continue without photos" to import the dive metadata alone.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: notifier.skipPhotoLinking,
          child: const Text('Continue without photos'),
        ),
      ],
    );
  }
}

/// Desktop branch: three stages — pre-pick, scanning, and resolved.
class _DesktopBranch extends StatelessWidget {
  const _DesktopBranch({required this.state, required this.notifier});

  final UniversalImportState state;
  final UniversalImportNotifier notifier;

  @override
  Widget build(BuildContext context) {
    // Stage 2: scanning.
    if (state.isLoading && state.photoRootDir != null) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Scanning...'),
        ],
      );
    }

    final resolved = state.resolvedPhotos;

    // Stage 1: no folder picked yet (and not currently scanning).
    if (state.photoRootDir == null || resolved == null) {
      return _PreResolutionActions(notifier: notifier);
    }

    // Stage 3: resolution complete — show summary.
    return _ResolvedSummary(
      state: state,
      notifier: notifier,
      resolved: resolved,
    );
  }
}

/// Stage 1 UI: prompt + Pick folder / Skip photos buttons.
class _PreResolutionActions extends StatelessWidget {
  const _PreResolutionActions({required this.notifier});

  final UniversalImportNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where are your photos stored? Submersion will search this '
          'folder (and its subfolders) for each referenced photo.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _pickFolder(notifier),
          icon: const Icon(Icons.folder_open),
          label: const Text('Pick folder'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: notifier.skipPhotoLinking,
          child: const Text('Skip photos'),
        ),
      ],
    );
  }
}

/// Stage 3 UI: "N found, M missing" plus Change folder / Skip remaining.
class _ResolvedSummary extends StatelessWidget {
  const _ResolvedSummary({
    required this.state,
    required this.notifier,
    required this.resolved,
  });

  final UniversalImportState state;
  final UniversalImportNotifier notifier;
  final List<ResolvedPhoto> resolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final found = resolved
        .where((r) => r.kind != PhotoResolutionKind.miss)
        .length;
    final missing = resolved.length - found;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$found found, $missing missing',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Root: ${state.photoRootDir}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _pickFolder(notifier),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Change folder'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: notifier.skipPhotoLinking,
              child: const Text('Skip remaining'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shared folder-picker helper. Uses the same `file_picker` entry point
/// the rest of the codebase uses (see `database_location_service.dart`,
/// `backup_settings_page.dart`).
Future<void> _pickFolder(UniversalImportNotifier notifier) async {
  final picked = await FilePicker.getDirectoryPath(
    dialogTitle: 'Select photo folder',
    lockParentWindow: true,
  );
  if (picked != null) {
    await notifier.setPhotoRoot(picked);
  }
}
