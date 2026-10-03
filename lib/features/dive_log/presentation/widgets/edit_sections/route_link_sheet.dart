import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_proximity.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the Dive Edit page's route sheet (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1). Every
/// change is reported through [onChanged] as a new draft; nothing is
/// written to the database here except a route the diver imports, which
/// the review page saves unlinked.
///
/// [entryTime] is the form's current entry time, which orders the link
/// candidates. An imported route is saved without a site, so on Save it
/// takes the dive's final site (`link` inherits it), not whatever site the
/// form showed when the file was imported.
Future<void> showRouteLinkSheet(
  BuildContext context, {
  required DiveRouteLinkDraft draft,
  required DateTime entryTime,
  required ValueChanged<DiveRouteLinkDraft> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RouteLinkSheet(
      draft: draft,
      entryTime: entryTime,
      onChanged: onChanged,
    ),
  );
}

class _RouteLinkSheet extends ConsumerStatefulWidget {
  const _RouteLinkSheet({
    required this.draft,
    required this.entryTime,
    required this.onChanged,
  });

  final DiveRouteLinkDraft draft;
  final DateTime entryTime;
  final ValueChanged<DiveRouteLinkDraft> onChanged;

  @override
  ConsumerState<_RouteLinkSheet> createState() => _RouteLinkSheetState();
}

class _RouteLinkSheetState extends ConsumerState<_RouteLinkSheet> {
  static final _log = LoggerService.forClass(_RouteLinkSheet);
  late DiveRouteLinkDraft _draft = widget.draft;

  /// Why the last import failed, shown inside the sheet: a snackbar would
  /// render on the page behind this modal sheet, out of sight.
  String? _error;

  void _update(DiveRouteLinkDraft next) {
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  /// Unlinked routes, plus originals the diver removed (still linked until
  /// Save), minus anything already in the draft, nearest the entry first.
  List<NavTrack> _candidates(List<NavTrack> unlinked) {
    final byId = {
      for (final route in [...unlinked, ..._draft.removed]) route.id: route,
    };
    return sortByProximityTo(
      byId.values.where((route) => !_draft.contains(route.id)),
      widget.entryTime,
    );
  }

  Future<void> _link(List<NavTrack> candidates) async {
    final chosen = await showModalBottomSheet<NavTrack>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final route in candidates)
            ListTile(
              key: ValueKey('route-sheet-candidate-${route.id}'),
              title: Text(route.displayName),
              onTap: () => Navigator.of(context).pop(route),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    _update(_draft.add(chosen));
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    setState(() => _error = null);

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final NavTrackImportPreview preview;
    try {
      preview = await ref
          .read(navTrackImportServiceProvider)
          .prepare(bytes, fileName: file.name);
    } on NavTrackParseException catch (e) {
      _log.warning('Route import rejected: ${e.message}');
      if (mounted) setState(() => _error = navTrackParseErrorText(l10n, e));
      return;
    } catch (e, stackTrace) {
      _log.error('Route import failed', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _error = l10n.navTrack_list_importFailed(e.toString()));
      }
      return;
    }
    if (!mounted) return;

    final result = await navigateToNavTrackReviewForResult(
      context,
      bytes,
      fileName: file.name,
      preview: preview,
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(navTrackRepositoryProvider)
        .getById(result.routeId, includePoints: false);
    if (saved == null || !mounted) return;
    final replaced = result.replacedRouteId;
    _update(
      replaced == null ? _draft.add(saved) : _draft.replaced(replaced, saved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final unlinked = ref.watch(unlinkedNavTracksProvider).value ?? const [];
    final candidates = _candidates(unlinked);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.navTrack_section_trackTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_draft.current.isEmpty)
              Text(l10n.navTrack_section_noTrackLinked),
            for (final route in _draft.current)
              ListTile(
                key: ValueKey('route-sheet-row-${route.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route),
                title: Text(route.displayName),
                subtitle: Text(
                  [
                    if (route.totalDistance != null)
                      units.formatDistance(route.totalDistance!),
                    // Only a route linked when the form opened can be this
                    // dive's primary yet; link() decides the rest on Save.
                    if (route.isPrimary && _draft.wasLinkedOnOpen(route.id))
                      l10n.navTrack_section_primaryTag,
                  ].join(' · '),
                ),
                trailing: IconButton(
                  key: ValueKey('route-sheet-remove-${route.id}'),
                  tooltip: l10n.navTrack_editSheet_removeTrackTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => _update(_draft.remove(route.id)),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (candidates.isNotEmpty)
                  OutlinedButton(
                    key: const ValueKey('route-sheet-link-button'),
                    onPressed: () => _link(candidates),
                    child: Text(l10n.navTrack_section_linkTrackButton),
                  ),
                OutlinedButton(
                  key: const ValueKey('route-sheet-import-button'),
                  onPressed: _import,
                  child: Text(l10n.navTrack_section_importButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
