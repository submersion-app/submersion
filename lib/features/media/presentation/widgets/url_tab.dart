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

import 'package:submersion/features/media/data/services/network_import_targets.dart';
import 'package:submersion/features/media/data/utils/url_validator.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_mode_panel.dart';
import 'package:submersion/features/media/presentation/widgets/network_signin_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/url_review_pane.dart';

/// URL tab in the photo picker.
///
/// Bulk paste-and-add flow. The user pastes a newline-separated list of
/// URLs (or types one at a time into the "Add URL" single-line field), each
/// line is validated against [UrlValidator], and the "Add" button is
/// enabled once at least one line is valid and no lines are invalid.
/// Tapping "Add" resolves the staged set through
/// [UrlTabNotifier.resolveDraft], gives every URL its dive or site, inserts
/// through [UrlTabNotifier.commitRequests], and shows an Undo snackbar.
///
/// The Manifest mode segment renders [ManifestModePanel].
class UrlTab extends ConsumerStatefulWidget {
  const UrlTab({super.key, this.target});

  /// What this picker session attaches its rows to, when it has an owner.
  ///
  /// A [DiveAttachTarget] attaches every added URL to that dive and a
  /// [SiteAttachTarget] to that site. With no target, the resolved URLs go
  /// through [MediaImportReviewPage] so each one is given a dive or a site
  /// before it is inserted.
  final MediaAttachTarget? target;

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
    final navigator = Navigator.of(context);
    final resolved = await notifier.resolveDraft();
    if (!mounted) return;

    final target = widget.target;
    if (target != null) {
      final ids = await notifier.commitRequests(
        requestsForTarget(resolved, target),
      );
      if (!mounted) return;
      _draftBecameRows();
      _showUndo(messenger, notifier, ids);
      return;
    }

    // No owner: every URL needs a dive or a site before it may land. The
    // draft stays in the field until Confirm, so backing out of the review
    // leaves the pasted URLs where they were.
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: candidatesFor(resolved),
          onConfirm: (targets) async {
            final requests = requestsFromReview(resolved, targets);
            final ids = await notifier.commitRequests(requests);
            if (mounted) _draftBecameRows();
            _showUndo(messenger, notifier, ids);
            return ImportReviewResult(
              linked: ids.length,
              skipped: resolved.length - requests.length,
            );
          },
        ),
      ),
    );
  }

  /// Syncs the multi-line controller with the draft the notifier just
  /// cleared, so the textarea visibly empties once rows exist.
  void _draftBecameRows() {
    _multiLine.text = '';
  }

  void _showUndo(
    ScaffoldMessengerState messenger,
    UrlTabNotifier notifier,
    List<String> ids,
  ) {
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
            const Expanded(child: ManifestModePanel()),
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
      const SizedBox(height: 16),
      Expanded(child: UrlReviewPane(state: state)),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canCommit && !state.resolving ? _commit : null,
          child: state.resolving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              // TODO(media): l10n
              : const Text('Add'),
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
