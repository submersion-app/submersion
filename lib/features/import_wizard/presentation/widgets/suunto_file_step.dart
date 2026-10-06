import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_file_adapter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('SuuntoFileStep');

/// Opens the platform picker for Suunto JSON exports. Injected so a widget
/// test never reaches the platform channel.
final suuntoJsonFilePickerProvider =
    Provider<Future<List<SuuntoJsonFile>> Function()>(
      (ref) => pickSuuntoJsonFiles,
    );

/// Picks one or more files and reads each handle's bytes. file_picker 12
/// handles have no local path on Android SAF, so the bytes are read from
/// the handle itself rather than from disk.
Future<List<SuuntoJsonFile>> pickSuuntoJsonFiles() async {
  final picked = await FilePicker.pickFiles(type: FileType.any);
  return [
    for (final file in picked)
      SuuntoJsonFile(name: file.name, bytes: await file.readAsBytes()),
  ];
}

/// The Suunto file import's only acquisition step (issue #1445): reads the
/// handed-over or picked Suunto app exports, lists each file with whether
/// it carries a recorded route or why it was skipped, and hands the dives
/// to the adapter.
class SuuntoFileStep extends ConsumerStatefulWidget {
  const SuuntoFileStep({
    super.key,
    required this.initialFiles,
    required this.onRead,
    this.previousResults = const [],
  });

  /// Files handed over by a hand-off, read when the step first opens.
  final List<SuuntoJsonFile> initialFiles;

  /// What the step read the last time it was on screen. The wizard's
  /// PageView rebuilds a step it returns to, so these are shown again
  /// instead of re-reading [initialFiles] over the diver's own pick.
  final List<SuuntoFileReadResult> previousResults;

  /// Every read file, dives and skipped ones alike.
  final void Function(List<SuuntoFileReadResult> results) onRead;

  @override
  ConsumerState<SuuntoFileStep> createState() => _SuuntoFileStepState();
}

class _SuuntoFileStepState extends ConsumerState<SuuntoFileStep> {
  List<SuuntoFileReadResult> _results = const [];
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    if (widget.previousResults.isNotEmpty) {
      _results = widget.previousResults;
      // Providers cannot be written during the first build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publish(_results);
      });
    } else if (widget.initialFiles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _read(widget.initialFiles);
      });
    }
  }

  void _publish(List<SuuntoFileReadResult> results) {
    widget.onRead(results);
    ref.read(suuntoFileDivesReadyProvider.notifier).state = results.any(
      (r) => r.dive != null,
    );
  }

  Future<void> _pick() async {
    final List<SuuntoJsonFile> files;
    try {
      files = await ref.read(suuntoJsonFilePickerProvider)();
    } catch (e, st) {
      // A handle that cannot be read (a revoked SAF grant, say) must not
      // end in silence; the diver can pick again.
      _log.warning('Could not read the picked files', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dropTarget_error_readFailed)),
      );
      return;
    }
    if (!mounted || files.isEmpty) return;
    await _read(files);
  }

  Future<void> _read(List<SuuntoJsonFile> files) async {
    setState(() => _reading = true);
    try {
      final results = <SuuntoFileReadResult>[];
      for (final file in files) {
        results.add(readSuuntoJsonFile(file));
        // Let the progress indicator paint between large files.
        await Future<void>.delayed(Duration.zero);
      }
      if (!mounted) return;
      _publish(results);
      setState(() => _results = results);
    } finally {
      // Never leave "Choose files" disabled behind a failed read.
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final readyCount = _results.where((r) => r.dive != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.suuntoFile_step_title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l10n.suuntoFile_step_description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _reading ? null : _pick,
            icon: _reading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open),
            label: Text(l10n.suuntoFile_step_chooseFiles),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.suuntoFile_step_readyCount(readyCount),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final result in _results) _FileRow(result: result),
          ],
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.result});

  final SuuntoFileReadResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dive = result.dive;
    final rejection = result.rejection;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        dive != null ? Icons.check_circle_outline : Icons.block,
        color: dive != null
            ? theme.colorScheme.primary
            : theme.colorScheme.error,
      ),
      title: Text(result.file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        dive != null
            ? (dive.route != null
                  ? l10n.suuntoFile_step_routeIncluded
                  : l10n.suuntoFile_step_noRoute)
            : _rejectionText(l10n, rejection!),
        style: dive != null ? null : TextStyle(color: theme.colorScheme.error),
      ),
    );
  }

  static String _rejectionText(
    AppLocalizations l10n,
    SuuntoFileRejection rejection,
  ) => switch (rejection) {
    SuuntoFileRejection.notJson => l10n.suuntoFile_rejection_notJson,
    SuuntoFileRejection.notSuuntoExport =>
      l10n.suuntoFile_rejection_notSuuntoExport,
    SuuntoFileRejection.notADive => l10n.suuntoFile_rejection_notADive,
  };
}
