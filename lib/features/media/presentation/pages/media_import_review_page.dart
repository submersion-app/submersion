import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/features/media/presentation/widgets/ambiguous_dive_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/import_preview_thumbnail.dart';
import 'package:submersion/l10n/l10n_extension.dart';

typedef ImportReviewConfirm =
    Future<ImportReviewResult> Function(Map<String, MediaAttachTarget> targets);

/// The pre-import review: every candidate resolves to a dive, a site, no
/// place ([allowUnplaced] only), or "not imported" before the caller writes
/// anything. Confident timestamp matches start checked; ambiguous and
/// unmatched candidates need a pick, one at a time or all the rest at once.
class MediaImportReviewPage extends ConsumerStatefulWidget {
  const MediaImportReviewPage({
    super.key,
    required this.candidates,
    required this.onConfirm,
    this.reportResult = true,
    this.allowUnplaced = false,
  });

  final List<ImportCandidate> candidates;
  final ImportReviewConfirm onConfirm;

  /// Whether Confirm says what it linked. False where nothing is linked
  /// yet: a species page in a sitting holds the photos until Save (issue
  /// #4527, phase 3).
  final bool reportResult;

  /// Whether a file may be kept in the library with no dive and no site
  /// (issue #5122). Only the library's own import offers it: a species page
  /// adds its photos to a dive or a site.
  final bool allowUnplaced;

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
    final result = await showSitePicker(context, useDeviceLocation: false);
    if (result is! SitePicked || !mounted) return;
    setState(() => _overrides[c.key] = SiteAttachTarget(result.site.id));
  }

  void _keepUnplaced(ImportCandidate c) =>
      setState(() => _overrides[c.key] = const UnplacedAttachTarget());

  /// Puts every candidate in [rest] (those with no target yet) on one site.
  Future<void> _allOnSite(List<ImportCandidate> rest) async {
    final result = await showSitePicker(context, useDeviceLocation: false);
    if (result is! SitePicked || !mounted) return;
    setState(() {
      for (final c in rest) {
        _overrides[c.key] = SiteAttachTarget(result.site.id);
      }
    });
  }

  void _allUnplaced(List<ImportCandidate> rest) => setState(() {
    for (final c in rest) {
      _overrides[c.key] = const UnplacedAttachTarget();
    }
  });

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
    if (!widget.reportResult) {
      Navigator.of(context).pop();
      return;
    }
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
      case EquipmentAttachTarget():
        return l10n.media_import_review_linkToGear;
      case UnplacedAttachTarget():
        return l10n.media_import_review_unplaced;
      case null:
        break;
    }
    if (c.error != null) return c.error!;
    if (_overrides.containsKey(c.key)) return l10n.media_import_review_skipped;
    // Say why nothing matched when the cause is the file's date rather than
    // the diver's log: no date at all, or only the file's modified time.
    if (c.takenAt == null) return l10n.media_import_review_noCaptureTime;
    return switch (s?.match.kind) {
      TimestampMatchKind.ambiguous => l10n.media_import_review_ambiguous,
      _ when c.takenAtSource == TakenAtSource.fileModifiedTime =>
        l10n.media_import_review_noMatchFileDate,
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
    // The rest: what no match, pick or bulk action has placed yet. A row the
    // diver unchecked stays out of it.
    final rest = [
      for (final (c, _, target) in rows)
        if (target == null && !_overrides.containsKey(c.key) && c.error == null)
          c,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.media_import_review_title)),
      body: Column(
        children: [
          if (rest.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('media_import_review_all_on_site'),
                    onPressed: _busy ? null : () => _allOnSite(rest),
                    icon: const Icon(Icons.place_outlined),
                    label: Text(l10n.media_import_review_allOnSite),
                  ),
                  if (widget.allowUnplaced)
                    OutlinedButton.icon(
                      key: const ValueKey('media_import_review_all_unplaced'),
                      onPressed: _busy ? null : () => _allUnplaced(rest),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(l10n.media_import_review_allUnplaced),
                    ),
                ],
              ),
            ),
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
                      switch (action) {
                        case 'dive':
                          _chooseDive(c, s);
                        case 'site':
                          _chooseSite(c);
                        case 'unplaced':
                          _keepUnplaced(c);
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
                      if (widget.allowUnplaced)
                        PopupMenuItem(
                          value: 'unplaced',
                          child: Text(l10n.media_import_review_keepUnplaced),
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
