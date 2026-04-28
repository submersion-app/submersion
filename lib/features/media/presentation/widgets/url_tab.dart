// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 15. The plan is intentionally light — it lists what the widget
// needs ("segmented control, multi-line field, per-line validation,
// 'Add URL' single-line, auto-match checkbox, 'Add' button" + a
// snackbar/undo wiring code block) and points at `FileReviewPane` as
// the structural template. The failing widget tests in
// `test/features/media/presentation/widgets/url_tab_test.dart` drive
// the contract for every visible string and finder used here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/utils/url_validator.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_signin_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/url_review_pane.dart';

/// URL tab in the photo picker.
///
/// Phase 3a / Task 15: bulk paste-and-add flow. The user pastes a
/// newline-separated list of URLs (or types one at a time into the
/// "Add URL" single-line field), each line is validated against
/// [UrlValidator], and the "Add" button is enabled once at least one
/// line is valid and no lines are invalid. Tapping "Add" forwards the
/// staged set to [NetworkFetchPipeline.ingest] via
/// [UrlTabNotifier.commit] and shows an Undo snackbar.
///
/// The Manifest mode segment is reserved for Phase 3b — its body is a
/// placeholder Card.
class UrlTab extends ConsumerStatefulWidget {
  const UrlTab({super.key});

  @override
  ConsumerState<UrlTab> createState() => _UrlTabState();
}

class _UrlTabState extends ConsumerState<UrlTab> {
  late final TextEditingController _multiLine;
  late final TextEditingController _singleLine;

  @override
  void initState() {
    super.initState();
    _multiLine = TextEditingController(
      text: ref.read(urlTabNotifierProvider).draftLines.join('\n'),
    );
    _singleLine = TextEditingController();
  }

  @override
  void dispose() {
    _multiLine.dispose();
    _singleLine.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final notifier = ref.read(urlTabNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final ids = await notifier.commit();
    if (!mounted) return;
    if (!context.mounted) return;
    // Sync the multi-line controller with the cleared draft state so
    // the textarea visibly empties after a successful commit.
    _multiLine.text = '';
    messenger.showSnackBar(
      SnackBar(
        // TODO(media): l10n, pluralization
        content: Text('Added ${ids.length} URL${ids.length == 1 ? '' : 's'}'),
        action: SnackBarAction(
          // TODO(media): l10n
          label: 'Undo',
          onPressed: () => notifier.undoCommit(ids),
        ),
      ),
    );
  }

  Future<void> _openSignInSheet(String hostname) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NetworkSignInSheet(hostname: hostname),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(urlTabNotifierProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeSegmentedControl(
            mode: state.mode,
            onChanged: (m) =>
                ref.read(urlTabNotifierProvider.notifier).setMode(m),
          ),
          const SizedBox(height: 16),
          if (state.mode == UrlTabMode.urls)
            ..._buildUrlsBody(context, state)
          else
            const _ManifestPlaceholderCard(),
        ],
      ),
    );
  }

  List<Widget> _buildUrlsBody(BuildContext context, UrlTabState state) {
    final results = state.draftLines
        .map((l) => MapEntry(l, UrlValidator.parse(l)))
        .toList();
    final invalidLines = results
        .where((e) => e.value is UrlValidationInvalid)
        .toList();
    final validCount = results.where((e) => e.value is UrlValidationOk).length;
    final canCommit = validCount > 0 && invalidLines.isEmpty;
    return [
      if (state.unauthenticatedHosts.isNotEmpty)
        _SignInBadgeRow(
          hosts: state.unauthenticatedHosts,
          onSignIn: _openSignInSheet,
        ),
      TextField(
        controller: _multiLine,
        minLines: 4,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          // TODO(media): l10n
          labelText: 'URLs (one per line)',
          // TODO(media): l10n
          hintText: 'https://example.com/photo.jpg',
          border: OutlineInputBorder(),
        ),
        onChanged: (text) =>
            ref.read(urlTabNotifierProvider.notifier).setDraft(text),
      ),
      if (invalidLines.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final entry in invalidLines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              // TODO(media): l10n
              '"${entry.key}": ${(entry.value as UrlValidationInvalid).message}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _singleLine,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          // TODO(media): l10n
          labelText: 'Add URL',
          // TODO(media): l10n
          hintText: 'https://example.com/photo.jpg',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (text) {
          final trimmed = text.trim();
          if (trimmed.isEmpty) return;
          ref.read(urlTabNotifierProvider.notifier).appendSingle(trimmed);
          // Mirror the appended URL in the multi-line draft so the
          // user sees a single source of truth.
          final lines = ref.read(urlTabNotifierProvider).draftLines;
          _multiLine.text = lines.join('\n');
          _singleLine.clear();
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Checkbox(
            value: state.autoMatchByDate,
            onChanged: (value) => ref
                .read(urlTabNotifierProvider.notifier)
                .setAutoMatchByDate(value ?? true),
          ),
          const Expanded(
            // TODO(media): l10n
            child: Text('Auto-match URLs to dives by date'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Expanded(child: UrlReviewPane(state: state)),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canCommit ? _commit : null,
          // TODO(media): l10n
          child: const Text('Add'),
        ),
      ),
    ];
  }
}

class _ModeSegmentedControl extends StatelessWidget {
  const _ModeSegmentedControl({required this.mode, required this.onChanged});

  final UrlTabMode mode;
  final ValueChanged<UrlTabMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UrlTabMode>(
      segments: const [
        // TODO(media): l10n
        ButtonSegment(value: UrlTabMode.urls, label: Text('URLs')),
        // TODO(media): l10n
        ButtonSegment(value: UrlTabMode.manifest, label: Text('Manifest')),
      ],
      selected: {mode},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

class _ManifestPlaceholderCard extends StatelessWidget {
  const _ManifestPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.upcoming_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            // TODO(media): l10n
            Text(
              'Manifest mode arrives in Phase 3b',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // TODO(media): l10n
            Text(
              'Soon you will be able to point Submersion at a JSON or '
              'CSV manifest URL and bulk-import its referenced media.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInBadgeRow extends StatelessWidget {
  const _SignInBadgeRow({required this.hosts, required this.onSignIn});

  final Set<String> hosts;
  final ValueChanged<String> onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final host in hosts)
            ActionChip(
              avatar: Icon(
                Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.onErrorContainer,
              ),
              backgroundColor: theme.colorScheme.errorContainer,
              labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer),
              // TODO(media): l10n
              label: const Text('Sign in'),
              tooltip: host,
              onPressed: () => onSignIn(host),
            ),
        ],
      ),
    );
  }
}
