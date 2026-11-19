import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_scroll_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_group_header.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sectioned presentation shared by the by-dive and timeline modes: one lazy
/// justified grid whose cells are group headers and thumbnails, so what is
/// built follows the viewport rather than the size of a group (issues #3826,
/// #4738), with the same near-end load-more contract as the flat grid.
class MediaLibraryGroupedList extends ConsumerStatefulWidget {
  const MediaLibraryGroupedList({
    super.key,
    required this.groups,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTileTap,
    required this.rowHeight,
    this.selectedIds = const {},
    this.isSelectionMode = false,
  });

  final List<MediaLibraryGroup> groups;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(MediaLibraryEntry entry) onTileTap;

  /// The height rows are packed at, from the size slider (issues #3297,
  /// #4738).
  final double rowHeight;

  /// Ids rendered with the selection overlay.
  final Set<String> selectedIds;

  /// Whether the surface is in multi-select, which can be true with nothing
  /// checked.
  final bool isSelectionMode;

  @override
  ConsumerState<MediaLibraryGroupedList> createState() =>
      _MediaLibraryGroupedListState();
}

class _MediaLibraryGroupedListState
    extends ConsumerState<MediaLibraryGroupedList> {
  MediaGroupHeaderMeasurer? _measurer;

  /// A linked dive's header label. Unlinked has no plain header: its section
  /// heading names it (issue #4224).
  String _diveHeaderLabel(
    BuildContext context,
    UnitFormatter units,
    DiveGroupHeader header,
  ) {
    final siteName = header.siteName;
    final parts = <String>[
      if (header.diveNumber != null) '#${header.diveNumber}',
      if (siteName != null && siteName.isNotEmpty) siteName,
    ];
    if (parts.isEmpty) {
      final date = header.diveDateTime;
      if (date != null) {
        return units.formatDate(date);
      }
      // A linked dive with no number, site or date still needs a visible
      // label: the header is this view's only route to that dive, and an
      // empty string renders a zero-size, untappable target.
      return context.l10n.media_library_untitledDiveHeader;
    }
    return parts.join(' · ');
  }

  /// A by-dive mode header that opens [route]. Inert while a selection is in
  /// progress, matching the tiles below it: a tap landing a few pixels high
  /// must not navigate away from a half-built selection.
  MediaGroupHeaderSpec _linkHeader(
    String label, {
    required String? route,
    required String hint,
  }) => MediaGroupHeaderSpec(
    kind: MediaGroupHeaderKind.dive,
    label: label,
    route: widget.isSelectionMode ? null : route,
    hint: hint,
  );

  /// [template] around [name] when it has text, else [fallback] on its own:
  /// an empty label renders a zero-size, untappable header, and the fallback
  /// inside the template would read "Site: Site".
  static String _named(
    String? name,
    String Function(String name) template,
    String fallback,
  ) {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : template(trimmed);
  }

  /// The section heading a by-dive group of [kind] opens when the group
  /// before it was of another kind (issue #4224). Dives, which come first,
  /// get none.
  MediaGroupHeaderSpec? _sectionFor(
    BuildContext context,
    MediaAttachmentKind kind,
  ) => switch (kind) {
    MediaAttachmentKind.dive => null,
    MediaAttachmentKind.site => MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.section,
      label: context.l10n.media_library_sectionSitePictures,
      icon: Icons.place_outlined,
    ),
    MediaAttachmentKind.equipment => MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.section,
      label: context.l10n.media_library_sectionEquipmentPictures,
      icon: Icons.build_outlined,
    ),
    MediaAttachmentKind.unlinked => MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.section,
      label: context.l10n.media_library_unlinkedHeader,
      icon: Icons.link_off,
    ),
  };

  /// Each group's headers, in order. The timeline carries a month header
  /// whenever the month changes between groups; the by-dive view a section
  /// heading whenever the kind of group changes (issue #4224), which the
  /// query's group order makes once per kind.
  List<List<MediaGroupHeaderSpec>> _headers(
    BuildContext context,
    UnitFormatter units,
  ) {
    DateTime? lastMonth;
    MediaAttachmentKind? lastKind;
    // The section heading [kind] opens, if the kind changed here.
    List<MediaGroupHeaderSpec> opening(MediaAttachmentKind kind) {
      final changed = kind != lastKind;
      lastKind = kind;
      final section = changed ? _sectionFor(context, kind) : null;
      return [?section];
    }

    final headers = <List<MediaGroupHeaderSpec>>[];
    for (final group in widget.groups) {
      switch (group.header) {
        case DateGroupHeader(:final monthStart, :final dayStart):
          headers.add([
            if (lastMonth != monthStart)
              MediaGroupHeaderSpec(
                kind: MediaGroupHeaderKind.month,
                label: units.formatMonthYear(monthStart),
              ),
            MediaGroupHeaderSpec(
              kind: MediaGroupHeaderKind.day,
              label: units.formatWeekdayMonthDay(dayStart),
            ),
          ]);
          lastMonth = monthStart;
        case DiveGroupHeader(diveId: null):
          // Unlinked: its section heading is its only header.
          headers.add(opening(MediaAttachmentKind.unlinked));
        case final DiveGroupHeader header:
          final diveId = header.diveId;
          headers.add([
            ...opening(MediaAttachmentKind.dive),
            _linkHeader(
              _diveHeaderLabel(context, units, header),
              route: '/dives/$diveId',
              hint: context.l10n.media_library_diveHeaderHint,
            ),
          ]);
        case SiteGroupHeader(:final siteId, :final siteName):
          headers.add([
            ...opening(MediaAttachmentKind.site),
            _linkHeader(
              _named(
                siteName,
                context.l10n.media_library_siteHeader,
                context.l10n.media_library_filter_site,
              ),
              route: '/sites/$siteId',
              hint: context.l10n.media_library_siteHeaderHint,
            ),
          ]);
        case EquipmentGroupHeader(:final equipmentId, :final name):
          headers.add([
            ...opening(MediaAttachmentKind.equipment),
            _linkHeader(
              _named(
                name,
                context.l10n.media_library_equipmentHeader,
                context.l10n.media_library_untitledEquipment,
              ),
              route: '/equipment/$equipmentId',
              hint: context.l10n.media_library_equipmentHeaderHint,
            ),
          ]);
      }
    }
    return headers;
  }

  /// Each group's section at [paneWidth]: its headers' heights, measured
  /// for that width, and its thumbnails' shapes.
  List<JustifiedSection> _sections(
    BuildContext context,
    List<List<MediaGroupHeaderSpec>> headers,
    Map<String, LearnedAspect> learned,
    double paneWidth,
  ) {
    final measurer = MediaGroupHeaderMeasurer.of(context);
    final current = _measurer;
    final kept = current != null && current.matches(measurer)
        ? current
        : _measurer = measurer;
    return [
      for (var g = 0; g < headers.length; g++)
        JustifiedSection(
          headerExtents: [
            for (final spec in headers[g]) kept.extentOf(spec, paneWidth),
          ],
          ratios: mediaLibraryRatios(widget.groups[g].entries, learned),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // The first layout waits for the learned shapes, as the flat grid does.
    final learned = ref.watch(mediaLearnedAspectsProvider).value;
    if (learned == null) return const SizedBox.shrink();
    final units = ref.watch(unitFormatterProvider);
    final headers = _headers(context, units);
    final groups = widget.groups;
    final selectedIds = widget.selectedIds;
    final isSelectionMode = widget.isSelectionMode;

    return JustifiedMediaScrollView(
      sectionsFor: (paneWidth) =>
          _sections(context, headers, learned, paneWidth),
      rowHeight: widget.rowHeight,
      hasMore: widget.hasMore,
      onLoadMore: widget.onLoadMore,
      padding: const EdgeInsets.only(bottom: 8),
      cellBuilder: (context, cell) {
        if (cell.isHeader) {
          final spec = headers[cell.section][cell.header];
          return MediaGroupHeader(
            spec: spec,
            onTap: () => context.pushOrReturnTo(spec.route!),
          );
        }
        final entry = groups[cell.section].entries[cell.tile];
        return MediaLibraryTile(
          entry: entry,
          selected: selectedIds.contains(entry.item.id),
          isSelectionMode: isSelectionMode,
          targetSize: mediaThumbnailDecodeTarget(cell.size),
          onImageSize: (size) => ref
              .read(mediaLearnedAspectsProvider.notifier)
              .report(entry.item, size),
          onTap: () => widget.onTileTap(entry),
        );
      },
    );
  }
}
