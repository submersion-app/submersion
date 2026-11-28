import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_grouping.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the photo picker for linking photos to [item] (issue #5046), with
/// the photos of [linkedIds] checked. Returns the ids checked when the
/// diver applies, the linked ones first, or null when they back out.
Future<List<String>?> showGearPhotoLinkSheet(
  BuildContext context, {
  required EquipmentItem item,
  required List<String> linkedIds,
}) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.9,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    expand: false,
    builder: (_, controller) => GearPhotoLinkSheet(
      item: item,
      linkedIds: linkedIds,
      scrollController: controller,
    ),
  ),
);

/// The photos of the item's dives (Dives with this gear) or of the whole
/// Library (All photos), grouped by dive, newest first, linked ones checked.
/// It opens on the item's dives, or on All photos for an item on no dive.
/// All photos reads the Library a page at a time, so a log of tens of
/// thousands of photos opens at once.
class GearPhotoLinkSheet extends ConsumerStatefulWidget {
  const GearPhotoLinkSheet({
    super.key,
    required this.item,
    required this.linkedIds,
    required this.scrollController,
  });

  final EquipmentItem item;

  /// The photos already linked, checked when the sheet opens.
  final List<String> linkedIds;
  final ScrollController scrollController;

  @override
  ConsumerState<GearPhotoLinkSheet> createState() => _GearPhotoLinkSheetState();
}

/// One tab's rows, read a page at a time.
class _Paged {
  /// Replaced, never added to, as each page arrives.
  List<MediaLibraryEntry> entries = const [];
  bool done = false;
  bool loading = false;
  bool failed = false;
}

class _GearPhotoLinkSheetState extends ConsumerState<GearPhotoLinkSheet> {
  /// Dives read per page of Dives with this gear.
  static const divesPerPage = 50;

  /// How close to the end of the list the next page is read, in pixels.
  static const _loadAhead = 600.0;

  late final Set<String> _initial = {...widget.linkedIds};

  /// In the order checked, so the photos linked here keep it.
  late Set<String> _checked = {..._initial};

  /// Null until the item's dives are known; then whether All photos shows.
  bool? _allPhotos;
  List<String> _diveIds = const [];

  final _dives = _Paged();
  int _diveCursor = 0;
  final _library = _Paged();
  MediaLibraryCursor? _libraryCursor;

  _Paged get _shown => _allPhotos == true ? _library : _dives;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_maybeLoad);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_maybeLoad);
    super.dispose();
  }

  /// Reads the next page of the tab shown when the list is near its end,
  /// or does not fill the sheet: a short page (one the linkable filter
  /// thinned, or a tall window) fires no scroll that would ask for more.
  void _maybeLoad() {
    final paged = _shown;
    if (_allPhotos == null || paged.done || paged.loading || paged.failed) {
      return;
    }
    final c = widget.scrollController;
    if (c.hasClients && c.position.extentAfter >= _loadAhead) return;
    _loadPage(paged);
  }

  Future<void> _loadPage(_Paged paged) async {
    paged.loading = true;
    try {
      final rows = paged == _library
          ? await _readLibraryPage()
          : await _readDivePage();
      if (!mounted) return;
      setState(() => paged.entries = [...paged.entries, ...rows]);
    } catch (_) {
      if (!mounted) return;
      setState(() => paged.failed = true);
    } finally {
      paged.loading = false;
    }
    // Once drawn, read on if the list still leaves the sheet unfilled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoad();
    });
  }

  Future<List<MediaLibraryEntry>> _readLibraryPage() async {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final page = await ref
        .read(mediaLibraryRepositoryProvider)
        .getPage(
          diverId: diverId,
          grouping: MediaLibraryGrouping.dive,
          after: _libraryCursor,
        );
    _libraryCursor = page.nextCursor;
    _library.done = page.nextCursor == null;
    return [
      for (final e in page.entries)
        if (_linkable(e.item)) e,
    ];
  }

  Future<List<MediaLibraryEntry>> _readDivePage() async {
    final end = (_diveCursor + divesPerPage).clamp(0, _diveIds.length);
    final slice = _diveIds.sublist(_diveCursor, end);
    _diveCursor = end;
    _dives.done = end >= _diveIds.length;
    if (slice.isEmpty) return const [];
    return ref.read(mediaGearRepositoryProvider).linkableEntriesOnDives(slice);
  }

  static bool _linkable(MediaItem m) =>
      !m.isDocument && !m.isSignature && !m.isGearPhoto;

  int get _changes =>
      _checked.difference(_initial).length +
      _initial.difference(_checked).length;

  void _toggle(MediaItem item) => setState(() {
    _checked = _checked.contains(item.id)
        ? {
            for (final id in _checked)
              if (id != item.id) id,
          }
        : {..._checked, item.id};
  });

  void _apply() => Navigator.of(context).pop([
    for (final id in widget.linkedIds)
      if (_checked.contains(id)) id,
    for (final id in _checked)
      if (!_initial.contains(id)) id,
  ]);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final diveIds = ref.watch(equipmentDiveIdsProvider(widget.item.id));
    // A failed read of the item's dives falls back to All photos, so the
    // diver can still link from the Library.
    if (_allPhotos == null && (diveIds.hasValue || diveIds.hasError)) {
      _diveIds = diveIds.value ?? const [];
      _allPhotos = _diveIds.isEmpty;
      if (_allPhotos!) _dives.done = true;
      // Dives with this gear says the read failed, not that there are none.
      if (diveIds.hasError) _dives.failed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeLoad();
      });
    }
    final all = _allPhotos;
    final paged = _shown;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l10n.equipment_divePhotos_sheetTitle(widget.item.name),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              if (all != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.equipment_divePhotos_divesWithGear),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.equipment_divePhotos_allPhotos),
                        ),
                      ],
                      selected: {all},
                      onSelectionChanged: (s) {
                        setState(() => _allPhotos = s.single);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _maybeLoad();
                        });
                      },
                    ),
                  ),
                ),
              if (all == null)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else
                ..._groups(
                  context,
                  [
                    for (final e in paged.entries)
                      (
                        key: _groupKey(e.item),
                        title: _groupTitle(context, e),
                        item: e.item,
                      ),
                  ],
                  loading: !paged.done && !paged.failed,
                  failed: paged.failed,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('gear_photo_link_apply'),
                  onPressed: _changes == 0 ? null : _apply,
                  child: Text(
                    _changes == 0
                        ? l10n.common_action_apply
                        : l10n.equipment_divePhotos_apply(_changes),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The group a row goes under, as the Library's By dive grouping: its
  /// dive, else the site it is attached to, else Unlinked. Gear photos are
  /// never offered, so there is no equipment group.
  static String _groupKey(MediaItem item) => switch (item) {
    MediaItem(diveId: final id?) => id,
    MediaItem(siteId: final id?) => 'site:$id',
    _ => 'unlinked',
  };

  /// A group's title, as the Library's: a dive's number, site and date; an
  /// attached site's name; or Unlinked.
  String _groupTitle(BuildContext context, MediaLibraryEntry e) {
    final l10n = context.l10n;
    if (e.item.diveId == null) {
      if (e.item.siteId == null) return l10n.media_library_unlinkedHeader;
      final name = e.attachedSiteName?.trim();
      return name == null || name.isEmpty
          ? l10n.media_library_filter_site
          : l10n.media_library_siteHeader(name);
    }
    final at = e.diveDateTime ?? e.item.takenAt;
    // The diver's own date format (dive times are wall-clock-as-UTC).
    final date = ref.read(unitFormatterProvider).formatDate(at);
    return [
      if (e.diveNumber != null) '#${e.diveNumber}',
      ?e.siteName,
      date,
    ].join(' · ');
  }

  /// Consecutive [rows] sharing a key as one group: its title, then its
  /// photos as a grid.
  List<Widget> _groups(
    BuildContext context,
    List<({String key, String title, MediaItem item})> rows, {
    bool loading = false,
    bool failed = false,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(unitFormatterProvider).settings;
    if (failed && rows.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.media_diveMediaSection_errorLoading,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ];
    }
    if (rows.isEmpty && !loading) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: MediaEmptyState(
              icon: Icons.photo_library_outlined,
              message: l10n.equipment_divePhotos_noPhotos,
            ),
          ),
        ),
      ];
    }
    // Merged by key in first-seen order, as the Library's groupByDive
    // does, so a group read across two pages stays one and no key repeats.
    final titles = <String, String>{};
    final items = <String, List<MediaItem>>{};
    for (final r in rows) {
      titles.putIfAbsent(r.key, () => r.title);
      items[r.key] = [...?items[r.key], r.item];
    }
    final groups = [
      for (final key in titles.keys)
        (key: key, title: titles[key]!, items: items[key]!),
    ];
    return [
      for (final g in groups) ...[
        SliverToBoxAdapter(
          child: Padding(
            key: ValueKey('gear_photo_link_group_${g.key}'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(g.title, style: theme.textTheme.titleSmall),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: g.items.length,
            itemBuilder: (context, index) {
              final item = g.items[index];
              final checked = _checked.contains(item.id);
              return GestureDetector(
                key: ValueKey('gear_photo_link_tile_${item.id}'),
                onTap: () => _toggle(item),
                child: MediaThumbnailTile(
                  item: item,
                  settings: settings,
                  isSelectionMode: true,
                  isSelected: checked,
                  semanticsLabel: l10n.equipment_photos_photoLabel,
                ),
              );
            },
          ),
        ),
      ],
      if (loading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
    ];
  }
}
