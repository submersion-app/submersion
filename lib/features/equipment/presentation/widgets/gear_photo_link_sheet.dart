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
/// the photos already [linked] checked. Returns the photos checked when the
/// diver applies, or null when they back out.
Future<List<MediaItem>?> showGearPhotoLinkSheet(
  BuildContext context, {
  required EquipmentItem item,
  required List<MediaItem> linked,
}) => showModalBottomSheet<List<MediaItem>>(
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
      linked: linked,
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
    required this.linked,
    required this.scrollController,
  });

  final EquipmentItem item;
  final List<MediaItem> linked;
  final ScrollController scrollController;

  @override
  ConsumerState<GearPhotoLinkSheet> createState() => _GearPhotoLinkSheetState();
}

class _GearPhotoLinkSheetState extends ConsumerState<GearPhotoLinkSheet> {
  late final Set<String> _initial = {for (final m in widget.linked) m.id};
  late final Set<String> _checked = {..._initial};
  late final Map<String, MediaItem> _known = {
    for (final m in widget.linked) m.id: m,
  };

  /// Null until the item's dives are known; then whether All photos shows.
  bool? _allPhotos;

  final List<MediaLibraryEntry> _library = [];
  MediaLibraryCursor? _cursor;
  bool _libraryDone = false;
  bool _loadingPage = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final c = widget.scrollController;
    if (_allPhotos == true && c.hasClients && c.position.extentAfter < 600) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_loadingPage || _libraryDone) return;
    _loadingPage = true;
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final page = await ref
          .read(mediaLibraryRepositoryProvider)
          .getPage(
            diverId: diverId,
            grouping: MediaLibraryGrouping.dive,
            after: _cursor,
          );
      if (!mounted) return;
      setState(() {
        _library.addAll([
          for (final e in page.entries)
            if (_linkable(e.item)) e,
        ]);
        _cursor = page.nextCursor;
        _libraryDone = page.nextCursor == null;
      });
    } finally {
      _loadingPage = false;
    }
  }

  static bool _linkable(MediaItem m) =>
      !m.isDocument && !m.isSignature && !m.isGearPhoto;

  int get _changes =>
      _checked.difference(_initial).length +
      _initial.difference(_checked).length;

  void _toggle(MediaItem item) => setState(() {
    _known[item.id] = item;
    if (!_checked.remove(item.id)) _checked.add(item.id);
  });

  void _apply() {
    final kept = [
      for (final m in widget.linked)
        if (_checked.contains(m.id)) m,
    ];
    final added = [
      for (final id in _checked)
        if (!_initial.contains(id)) ?_known[id],
    ];
    Navigator.of(context).pop([...kept, ...added]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final diveIds = ref.watch(equipmentDiveIdsProvider(widget.item.id));
    if (_allPhotos == null && diveIds.hasValue) {
      _allPhotos = diveIds.value!.isEmpty;
      if (_allPhotos!) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
      }
    }
    final all = _allPhotos;

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
                        if (s.single && _library.isEmpty) _loadPage();
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
              else if (all)
                ..._groups(context, [
                  for (final e in _library)
                    (
                      key: e.item.diveId ?? '',
                      title: _libraryTitle(context, e),
                      item: e.item,
                    ),
                ], loading: !_libraryDone)
              else
                ...switch (ref.watch(
                  linkableMediaOnEquipmentDivesProvider(widget.item.id),
                )) {
                  AsyncData(:final value) => _groups(context, [
                    for (final m in value)
                      (
                        key: m.diveId ?? '',
                        title: _dateTitle(context, m.takenAt),
                        item: m,
                      ),
                  ]),
                  _ => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ],
                },
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

  String _dateTitle(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context).formatMediumDate(at);

  String _libraryTitle(BuildContext context, MediaLibraryEntry e) {
    final at = e.diveDateTime ?? e.item.takenAt;
    final date = _dateTitle(context, at);
    final parts = [
      if (e.diveNumber != null) '#${e.diveNumber}',
      ?e.siteName,
      date,
    ];
    return parts.join(' · ');
  }

  /// Consecutive [rows] sharing a key as one group: its title, then its
  /// photos as a grid.
  List<Widget> _groups(
    BuildContext context,
    List<({String key, String title, MediaItem item})> rows, {
    bool loading = false,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(unitFormatterProvider).settings;
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
    final groups = <({String key, String title, List<MediaItem> items})>[];
    for (final r in rows) {
      if (groups.isEmpty || groups.last.key != r.key) {
        groups.add((key: r.key, title: r.title, items: [r.item]));
      } else {
        groups.last.items.add(r.item);
      }
    }
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
