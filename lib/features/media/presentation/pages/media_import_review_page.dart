import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/features/media/presentation/widgets/ambiguous_dive_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/import_preview_thumbnail.dart';
import 'package:submersion/features/media/presentation/widgets/site_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

typedef ImportReviewConfirm =
    Future<ImportReviewResult> Function(Map<String, MediaAttachTarget> targets);

/// The pre-import review: every candidate resolves to a dive, a site, or
/// "not imported" before the caller writes anything. Confident timestamp
/// matches start checked; ambiguous and unmatched candidates need a pick.
class MediaImportReviewPage extends ConsumerStatefulWidget {
  const MediaImportReviewPage({
    super.key,
    required this.candidates,
    required this.onConfirm,
  });

  final List<ImportCandidate> candidates;
  final ImportReviewConfirm onConfirm;

  @override
  ConsumerState<MediaImportReviewPage> createState() =>
      _MediaImportReviewPageState();
}

class _MediaImportReviewPageState extends ConsumerState<MediaImportReviewPage> {
  /// Explicit user decisions, keyed by candidate. A null value means "skip
  /// this one" (a confident match the user unchecked). Absent means "use
  /// the suggestion".
  final Map<String, MediaAttachTarget?> _overrides = {};
  bool _busy = false;

  ImportSuggestion? _suggestionFor(ImportCandidate c) {
    final takenAt = c.takenAt;
    if (takenAt == null) return null;
    return ref.watch(importSuggestionProvider(takenAt)).value;
  }

  MediaAttachTarget? _targetFor(ImportCandidate c, ImportSuggestion? s) {
    if (_overrides.containsKey(c.key)) return _overrides[c.key];
    final match = s?.match;
    if (match != null && match.kind == TimestampMatchKind.confident) {
      return DiveAttachTarget(match.diveId!);
    }
    return null;
  }

  Future<void> _chooseDive(ImportCandidate c, ImportSuggestion? s) async {
    final match = s?.match;
    final diveId = match != null && match.kind == TimestampMatchKind.ambiguous
        ? await showAmbiguousDiveSheet(context, match.candidateDiveIds)
        : await showDivePickerSheet(context);
    if (diveId == null || !mounted) return;
    setState(() => _overrides[c.key] = DiveAttachTarget(diveId));
  }

  Future<void> _chooseSite(ImportCandidate c) async {
    final siteId = await showSitePickerSheet(context);
    if (siteId == null || !mounted) return;
    setState(() => _overrides[c.key] = SiteAttachTarget(siteId));
  }

  void _toggle(ImportCandidate c, ImportSuggestion? s) {
    final current = _targetFor(c, s);
    final confident = s?.match.kind == TimestampMatchKind.confident;
    setState(() {
      if (current != null) {
        _overrides[c.key] = null;
      } else if (confident) {
        _overrides.remove(c.key);
      }
    });
    if (current == null && !confident) {
      _chooseDive(c, s);
    }
  }

  Future<void> _confirm(Map<String, MediaAttachTarget> targets) async {
    setState(() => _busy = true);
    final ImportReviewResult result;
    try {
      result = await widget.onConfirm(targets);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.media_import_review_result(
            result.linked,
            result.skipped,
            result.failures.length,
          ),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  String _subtitle(
    BuildContext context,
    ImportCandidate c,
    ImportSuggestion? s,
    MediaAttachTarget? target,
  ) {
    final l10n = context.l10n;
    switch (target) {
      case DiveAttachTarget(:final diveId):
        final number = s?.match.diveId == diveId ? s?.diveNumber : null;
        return number == null
            ? l10n.media_import_review_linkToDive
            : l10n.media_import_review_linkChip(number);
      case SiteAttachTarget():
        return l10n.media_import_review_linkToSite;
      case null:
        break;
    }
    if (c.error != null) return c.error!;
    if (_overrides.containsKey(c.key)) return l10n.media_import_review_skipped;
    return switch (s?.match.kind) {
      TimestampMatchKind.ambiguous => l10n.media_import_review_ambiguous,
      _ => l10n.media_import_review_noMatch,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final targets = <String, MediaAttachTarget>{};
    final rows = <(ImportCandidate, ImportSuggestion?, MediaAttachTarget?)>[];
    for (final c in widget.candidates) {
      final s = _suggestionFor(c);
      final target = _targetFor(c, s);
      if (target != null) targets[c.key] = target;
      rows.add((c, s, target));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.media_import_review_title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final (c, s, target) = rows[index];
                final subtitle = _subtitle(context, c, s, target);
                final preview = c.preview;
                // A plain ListTile rather than CheckboxListTile: that widget
                // has two slots (control and `secondary`) and the row needs
                // three, since the art sits between the checkbox and the
                // title.
                return ListTile(
                  onTap: _busy ? null : () => _toggle(c, s),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: target != null,
                        onChanged: _busy ? null : (_) => _toggle(c, s),
                      ),
                      if (preview != null) ...[
                        const SizedBox(width: 4),
                        ImportPreviewThumbnail(preview: preview),
                      ],
                    ],
                  ),
                  title: Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    style: c.error != null && target == null
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (action) {
                      if (action == 'dive') {
                        _chooseDive(c, s);
                      } else {
                        _chooseSite(c);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'dive',
                        child: Text(l10n.media_import_review_chooseDive),
                      ),
                      PopupMenuItem(
                        value: 'site',
                        child: Text(l10n.media_import_review_chooseSite),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: targets.isEmpty || _busy
                    ? null
                    : () => _confirm(targets),
                child: Text(l10n.media_import_review_confirm(targets.length)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
