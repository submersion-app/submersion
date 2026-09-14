import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_equipment_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pushes the route review page for [bytes] freshly picked/dropped as
/// [fileName] and returns once the diver leaves it (whether or not they
/// saved). Every entry point that recognises a Seacraft ENC file --
/// the universal import wizard's hand-off card, the GPS logger's "Import
/// track", the routes area's own import button, the dive detail section's
/// import button -- calls this rather than building the page itself, so a
/// route path or a button label never needs to be duplicated.
///
/// [preselectedDiveId] is a hint only, used to pre-select that dive in the
/// link proposal once the preview loads (e.g. importing from a dive's own
/// "Underwater Route" section, where the dive is already known); it does
/// not skip the parse or the review step.
Future<void> navigateToNavTrackReview(
  BuildContext context,
  Uint8List bytes, {
  required String fileName,
  String? preselectedDiveId,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => NavTrackImportReviewPage(
        bytes: bytes,
        fileName: fileName,
        preselectedDiveId: preselectedDiveId,
      ),
    ),
  );
}

/// Reviews a parsed Seacraft ENC route before it is written: the link
/// proposal, the dive site, warnings, and the save action (spec
/// 2026-09-10-underwater-nav-track-design.md, "Review page").
///
/// Parsing happens once, in [initState] (against the service's [prepare],
/// or reused from [preview] when a caller already parsed the file --
/// the routes area's own import button does this today through
/// `pendingNavTrackImportProvider`, to show its own error handling around
/// a failed parse before ever pushing this page); nothing is written until
/// [_save] calls its `commit`.
class NavTrackImportReviewPage extends ConsumerStatefulWidget {
  const NavTrackImportReviewPage({
    super.key,
    required this.bytes,
    required this.fileName,
    this.preselectedDiveId,
    this.preview,
  });

  final Uint8List bytes;
  final String fileName;
  final String? preselectedDiveId;

  /// Already-parsed preview, when a caller (e.g. the routes area's import
  /// button) ran `NavTrackImportService.prepare` itself. Null re-parses
  /// [bytes] in [initState].
  final NavTrackImportPreview? preview;

  @override
  ConsumerState<NavTrackImportReviewPage> createState() =>
      _NavTrackImportReviewPageState();
}

class _NavTrackImportReviewPageState
    extends ConsumerState<NavTrackImportReviewPage> {
  late final Future<NavTrackImportPreview> _previewFuture;

  Dive? _selectedDive;
  bool _diveChoiceInitialized = false;
  String? _siteId;
  String? _siteName;

  /// True once the diver has explicitly picked a site through [_pickSite],
  /// so a later dive selection never silently overwrites their own choice.
  bool _siteChosenManually = false;
  String? _equipmentId;
  String? _equipmentName;
  bool _replaceDuplicate = false;
  bool _busy = false;
  String? _error;

  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _previewFuture = widget.preview != null
        ? Future.value(widget.preview)
        : ref
              .read(navTrackImportServiceProvider)
              .prepare(widget.bytes, fileName: widget.fileName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// The link proposal defaults to the unique overlap match, or to
  /// [widget.preselectedDiveId] when the caller already knows the dive;
  /// several candidates or none leave the route unlinked until the diver
  /// chooses. Runs once, the first time the preview is available.
  void _initializeDiveChoice(NavTrackImportPreview preview) {
    if (_diveChoiceInitialized) return;
    _diveChoiceInitialized = true;
    if (widget.preselectedDiveId != null) {
      _selectedDive = preview.candidateDives
          .where((d) => d.id == widget.preselectedDiveId)
          .firstOrNull;
    }
    _selectedDive ??= preview.candidateDives.length == 1
        ? preview.candidateDives.single
        : null;
    _applySiteFromSelectedDive();
  }

  /// Pre-fills the site from [_selectedDive]'s own hydrated site, unless the
  /// diver has already explicitly picked one through [_pickSite]. Without
  /// this, accepting or picking a dive that already has a site left the
  /// route with no default anchor unless the diver picked the same site
  /// again by hand.
  ///
  /// Also clears a previously pre-filled site when the newly selected dive
  /// has none (or none is selected at all): otherwise switching from a
  /// site-bearing dive to one with no site left the old site attached, even
  /// though it no longer matches the current selection.
  void _applySiteFromSelectedDive() {
    if (_siteChosenManually) return;
    final site = _selectedDive?.site;
    _siteId = site?.id;
    _siteName = site?.name;
  }

  Future<void> _pickSite() async {
    final result = await showModalBottomSheet<DiveSite>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => SitePickerSheet(
          scrollController: scrollController,
          selectedSiteId: _siteId,
          onSiteSelected: (site) => Navigator.of(sheetContext).pop(site),
          // Creating a brand-new site from mid-review is a separate flow
          // this page does not open; the diver can still pick one already
          // in their log, or leave the route unanchored and set a site
          // later from the routes area.
          onCreateNewSite: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _siteId = result.id;
        _siteName = result.name;
        _siteChosenManually = true;
      });
    }
  }

  /// Distinguishes "the diver tapped the sheet's own no-equipment row" from
  /// "the sheet was dismissed without a choice" (backdrop tap, close
  /// button): [showModalBottomSheet] resolves to null for the latter, so
  /// the sheet pops this sentinel rather than a bare null for the former,
  /// and only it clears an existing selection.
  static const Object _noEquipmentChosen = Object();

  Future<void> _pickEquipment() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) =>
            NavTrackEquipmentPickerSheet(
              scrollController: scrollController,
              selectedEquipmentId: _equipmentId,
              onEquipmentSelected: (item) =>
                  Navigator.of(sheetContext).pop(item ?? _noEquipmentChosen),
            ),
      ),
    );
    if (result == null) return; // dismissed without a choice
    setState(() {
      if (result is EquipmentItem) {
        _equipmentId = result.id;
        _equipmentName = result.name;
      } else {
        _equipmentId = null;
        _equipmentName = null;
      }
    });
  }

  String _segmentSummary(
    AppLocalizations l10n,
    NavTrackSegmentation segmentation,
  ) {
    final underwater = segmentation.kinds
        .where((k) => k == NavTrackSampleKind.underwater)
        .length;
    final surface = segmentation.kinds
        .where((k) => k == NavTrackSampleKind.surfaceReckoned)
        .length;
    if (segmentation.fixEvents.isEmpty) {
      return l10n.navTrack_review_segmentSummaryNoFix(underwater);
    }
    final event = segmentation.fixEvents.first;
    final dNorth = event.afterNorth - event.beforeNorth;
    final dEast = event.afterEast - event.beforeEast;
    final vector = math.sqrt(dNorth * dNorth + dEast * dEast).round();
    return l10n.navTrack_review_segmentSummaryWithFix(
      underwater,
      surface,
      vector,
    );
  }

  Future<void> _save(NavTrackImportPreview preview) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _nameController.text.trim();
      // Commit the replacement before touching the duplicate it replaces:
      // a database/codec/sync failure in commit() must leave the prior
      // recording in place, since the review action was "replace", not
      // "delete then maybe get a new one". Deleting first and only then
      // committing would permanently lose the original route on any
      // failure in between.
      final id = await ref
          .read(navTrackImportServiceProvider)
          .commit(
            parsed: preview.parsed,
            sourceRef: preview.sourceRef,
            dive: _selectedDive,
            siteId: _siteId,
            name: name.isEmpty ? null : name,
            deviceName: _equipmentName,
            equipmentId: _equipmentId,
          );
      if (_replaceDuplicate && preview.duplicateOfRouteId != null) {
        await ref
            .read(navTrackRepositoryProvider)
            .delete(preview.duplicateOfRouteId!);
      }
      if (!mounted) return;
      // Literal path: the routes-area detail page lives in another agent's
      // work on this branch and is not yet guaranteed to exist under this
      // exact route name at the time this file is written.
      context.go('/nav-routes/$id');
    } on NavTrackParseException catch (e) {
      setState(() {
        _busy = false;
        _error = navTrackParseErrorText(l10n, e);
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = l10n.navTrack_review_saveError(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTrack_review_title)),
      body: FutureBuilder<NavTrackImportPreview>(
        future: _previewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = snapshot.error;
          if (error != null) {
            final message = error is NavTrackParseException
                ? navTrackParseErrorText(l10n, error)
                : l10n.navTrack_review_importError(error.toString());
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, textAlign: TextAlign.center),
              ),
            );
          }
          final preview = snapshot.data!;
          _initializeDiveChoice(preview);
          return _buildReview(context, l10n, units, preview);
        },
      ),
    );
  }

  Widget _buildReview(
    BuildContext context,
    AppLocalizations l10n,
    UnitFormatter units,
    NavTrackImportPreview preview,
  ) {
    final theme = Theme.of(context);
    final points = preview.parsed.points;
    final start = DateTime.fromMillisecondsSinceEpoch(
      points.first.timestamp * 1000,
      isUtc: true,
    );
    final end = DateTime.fromMillisecondsSinceEpoch(
      points.last.timestamp * 1000,
      isUtc: true,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(preview.sourceRef, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.navTrack_review_sourceLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.navTrack_review_nameHint,
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.navTrack_review_equipment, style: theme.textTheme.titleSmall),
        ListTile(
          key: const ValueKey('nav-track-equipment-picker'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.directions_boat_filled_outlined),
          title: Text(_equipmentName ?? l10n.navTrack_review_noEquipmentChosen),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickEquipment,
        ),
        const SizedBox(height: 24),
        _SummaryGrid(units: units, preview: preview, start: start, end: end),
        const SizedBox(height: 16),
        Text(
          _segmentSummary(l10n, preview.segmentation),
          key: const ValueKey('nav-track-segment-summary'),
          style: theme.textTheme.bodyMedium,
        ),
        if (preview.hasNoMovement) ...[
          const SizedBox(height: 12),
          _WarningCard(
            key: const ValueKey('nav-track-warning-no-movement'),
            text: l10n.navTrack_review_warningNoMovement,
          ),
        ],
        if (preview.duplicateOfRouteId != null) ...[
          const SizedBox(height: 12),
          _WarningCard(
            key: const ValueKey('nav-track-warning-duplicate'),
            text: l10n.navTrack_review_warningDuplicate,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.navTrack_review_replaceLabel),
                Checkbox(
                  value: _replaceDuplicate,
                  onChanged: (v) =>
                      setState(() => _replaceDuplicate = v ?? false),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          l10n.navTrack_review_linkToDive,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _DiveLinkPicker(
          candidates: preview.candidateDives,
          selected: _selectedDive,
          units: units,
          onChanged: (dive) => setState(() {
            _selectedDive = dive;
            _applySiteFromSelectedDive();
          }),
        ),
        const SizedBox(height: 24),
        Text(l10n.navTrack_review_diveSite, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        ListTile(
          key: const ValueKey('nav-track-site-picker'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place_outlined),
          title: Text(_siteName ?? l10n.navTrack_review_noSiteChosen),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickSite,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('nav-track-import-save'),
          onPressed: _busy ? null : () => _save(preview),
          child: Text(l10n.navTrack_common_save),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.units,
    required this.preview,
    required this.start,
    required this.end,
  });

  final UnitFormatter units;
  final NavTrackImportPreview preview;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = preview.stats;
    final duration = Duration(seconds: stats.durationSeconds);
    final durationText =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    final rows = <(String, String)>[
      (
        l10n.navTrack_review_row_start,
        '${units.formatDate(start)} ${units.formatTime(start)}',
      ),
      (
        l10n.navTrack_review_row_end,
        '${units.formatDate(end)} ${units.formatTime(end)}',
      ),
      (l10n.navTrack_review_row_duration, durationText),
      (
        l10n.navTrack_review_row_distance,
        units.formatDistance(stats.totalDistance),
      ),
      (l10n.navTrack_review_row_maxDepth, units.formatDepth(stats.maxDepth)),
      if (stats.maxSpeed != null)
        (l10n.navTrack_review_row_maxSpeed, units.formatSpeed(stats.maxSpeed!)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DiveLinkPicker extends StatelessWidget {
  const _DiveLinkPicker({
    required this.candidates,
    required this.selected,
    required this.units,
    required this.onChanged,
  });

  final List<Dive> candidates;
  final Dive? selected;
  final UnitFormatter units;
  final ValueChanged<Dive?> onChanged;

  // A minimal inline picker: candidates ordered by NavTrackMatcher's own
  // overlap ranking, plus "leave unlinked". The fuller `DiveLinkPicker`
  // widget (design spec's own name for the shared dive/route picker) is
  // being built by another agent on this branch for the dive detail
  // section and the routes-area detail page; once it exists, this can
  // delegate to it instead of its own RadioListTile column.
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RadioGroup<String?>(
      groupValue: selected?.id,
      onChanged: (id) =>
          onChanged(candidates.where((d) => d.id == id).firstOrNull),
      child: Column(
        children: [
          RadioListTile<String?>(
            key: const ValueKey('nav-track-link-unlinked'),
            value: null,
            dense: true,
            title: Text(l10n.navTrack_review_leaveUnlinked),
          ),
          for (final dive in candidates)
            RadioListTile<String?>(
              key: ValueKey('nav-track-link-${dive.id}'),
              value: dive.id,
              dense: true,
              title: Text(
                '${units.formatDate(dive.effectiveEntryTime)} '
                '${units.formatTime(dive.effectiveEntryTime)}',
              ),
            ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
