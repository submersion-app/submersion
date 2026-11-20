import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_new_sitting.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/maps/presentation/widgets/locked_map_scroll_passthrough.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/gear_here_section.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_section.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_delete_usage.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/data/services/dive_center_edit_save_service.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_cards.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_routes.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_rental_sitting.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';

part 'dive_center_detail_page_body.dart';
part 'dive_center_detail_page_creating.dart';
part 'dive_center_detail_page_dives.dart';
part 'dive_center_detail_page_editing.dart';

/// A dive centre's page. It opens locked and edits in place (issue
/// #4527).

class DiveCenterDetailPage extends ConsumerStatefulWidget {
  final String centerId;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends.
  final VoidCallback? onSittingEnded;

  /// A new dive centre (issue #4527, phase 3, plan 11): the page opened
  /// unlocked on a centre not yet created.
  final bool newDiveCenter;

  /// The pane's own: given the new centre's id once created.
  final void Function(String centerId)? onCreated;

  /// The pane's own: told when a new centre's page leaves uncreated.
  final VoidCallback? onCreateCancelled;

  const DiveCenterDetailPage({
    super.key,
    required this.centerId,
    this.embedded = false,
    this.onDeleted,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newDiveCenter = false,
       onCreated = null,
       onCreateCancelled = null;

  /// A new dive centre's page.
  const DiveCenterDetailPage.newDiveCenter({
    super.key,
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : newDiveCenter = true,
       centerId = '',
       onDeleted = null,
       openUnlocked = false,
       onSittingEnded = null;

  @override
  ConsumerState<DiveCenterDetailPage> createState() =>
      _DiveCenterDetailPageState();
}

class _DiveCenterDetailPageState extends ConsumerState<DiveCenterDetailPage>
    with
        RecordEditHost<DiveCenterDetailPage, DiveCenter>,
        RecordOpenUnlocked<DiveCenterDetailPage, DiveCenter>,
        _DiveCenterDetailPageEditing,
        RecordCreating<DiveCenterDetailPage, DiveCenter>,
        _DiveCenterDetailPageCreating {
  bool _hasRedirected = false;

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isCreating) {
      return newRecordWaiting(context) ?? _centerPage(newRecordSeed!);
    }
    // Desktop redirect: a root visit (deep link, sidebar) moves into the
    // master-detail split. A pushed page, opened from a dive's details
    // say, stays put: the redirect's go() would erase the page under it
    // and its back arrow (#3292).
    if (!_hasRedirected &&
        shouldRedirectToMasterDetail(
          context,
          embedded: widget.embedded,
          viewMode: ref.read(diveCenterListViewModeProvider),
        )) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(
            diveCenterPaneLocation(
              widget.centerId,
              openUnlocked: widget.openUnlocked,
            ),
          );
        }
      });
    }

    final centerAsync = ref.watch(diveCenterByIdProvider(widget.centerId));
    followStored(diveCenterByIdProvider(widget.centerId));

    return centerAsync.when(
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            ),
      error: (error, stack) => widget.embedded
          ? Center(
              child: Text(
                context.l10n.diveCenters_error_generic(error.toString()),
              ),
            )
          : Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Text(
                  context.l10n.diveCenters_error_generic(error.toString()),
                ),
              ),
            ),
      data: (stored) {
        if (stored == null) {
          return widget.embedded
              ? Center(child: Text(context.l10n.diveCenters_error_notFound))
              : Scaffold(
                  appBar: AppBar(),
                  body: Center(
                    child: Text(context.l10n.diveCenters_error_notFound),
                  ),
                );
        }

        return _centerPage(stored);
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final DiveCenter center;

  /// The card's pencil.
  final Widget? pencil;

  const _HeaderSection({required this.center, this.pencil});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DiveCenterAvatar(
                logo: center.logo,
                radius: 32,
                shape: DiveCenterAvatarShape.roundedSquare,
                cornerRadius: 12,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            center.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        ?pencil,
                      ],
                    ),
                    if (center.isPermanentlyClosed) ...[
                      const SizedBox(height: 4),
                      const _ClosedNote(),
                    ],
                    if (center.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < center.rating!.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 20,
                              color: Colors.amber.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatRatingForDisplay(center.rating!),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (center.displayLocation != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    center.displayLocation!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
          if (center.hasStreetAddress) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    center.formattedAddress ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          if (center.affiliations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: center.affiliations.map((affiliation) {
                return Chip(
                  label: Text(affiliation),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final DiveCenter center;
  final UnitFormatter units;

  /// The card's pencil.
  final Widget? pencil;

  /// Whether the title shows when there is nothing under it.
  final bool showEmpty;

  const _ContactSection({
    required this.center,
    required this.units,
    this.pencil,
    this.showEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final opens = center.fillOpensAt;
    final closes = center.fillClosesAt;
    final hasContact =
        center.phone != null ||
        center.email != null ||
        center.website != null ||
        (opens != null && closes != null);

    if (!hasContact && !showEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.diveCenters_section_contact,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?pencil,
            ],
          ),
          const SizedBox(height: 12),
          if (center.phone != null)
            _ContactTile(
              icon: Icons.phone_outlined,
              label: context.l10n.diveCenters_label_phone,
              value: center.phone!,
              onTap: () => _launchPhone(center.phone!),
              onLongPress: () => _copyToClipboard(context, center.phone!),
            ),
          if (center.email != null)
            _ContactTile(
              icon: Icons.email_outlined,
              label: context.l10n.diveCenters_label_email,
              value: center.email!,
              onTap: () => _launchEmail(center.email!),
              onLongPress: () => _copyToClipboard(context, center.email!),
            ),
          if (center.website != null)
            _ContactTile(
              icon: Icons.language_outlined,
              label: context.l10n.diveCenters_label_website,
              value: center.website!,
              onTap: () => _launchWebsite(center.website!),
              onLongPress: () => _copyToClipboard(context, center.website!),
            ),
          // Shown nowhere before (issue #4527): the station's daily window.
          if (opens != null && closes != null)
            ListTile(
              key: const ValueKey('dive_center_fill_hours'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_gas_station_outlined),
              title: Text(
                '${units.formatMinutesOfDay(opens)}'
                '\u2013${units.formatMinutesOfDay(closes)}',
              ),
              subtitle: Text(context.l10n.diveCenters_section_fillHours),
            ),
        ],
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWebsite(String website) async {
    var url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.common_snackbar_copiedToClipboard)),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String notes;

  /// The card's pencil.
  final Widget? pencil;

  const _NotesSection({required this.notes, this.pencil});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.diveCenters_section_notes,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?pencil,
            ],
          ),
          const SizedBox(height: 8),
          MarkdownNotesView(notes),
        ],
      ),
    );
  }
}

class _MapSection extends ConsumerStatefulWidget {
  final DiveCenter center;

  const _MapSection({required this.center});

  @override
  ConsumerState<_MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends ConsumerState<_MapSection> {
  final MapController _fullController = MapController();

  @override
  Widget build(BuildContext context) {
    final center = widget.center;
    final colorScheme = Theme.of(context).colorScheme;
    final centerLocation = LatLng(center.latitude!, center.longitude!);

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            LockedMapScrollPassthrough(
              child: FlutterMap(
                key: ValueKey('${center.latitude}_${center.longitude}'),
                options: MapOptions(
                  initialCenter: centerLocation,
                  initialZoom: 14.0,
                  minZoom: 2.0,
                  maxZoom: 18.0,
                  // Locked: the preview sits in the scrolling detail page, and
                  // a map that takes gestures there catches the wheel or drag
                  // as soon as it scrolls under the pointer (issue #3156). The
                  // fullscreen button opens the interactive map.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  submersionTileLayer(ref),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: centerLocation,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onPrimary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: DiveCenterMarkerGlyph(
                              logo: center.logo,
                              radius: DiveCenterMarkerGlyph.radiusFor(50),
                              iconColor: colorScheme.onPrimary,
                              iconSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const MapAttribution(),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                child: Semantics(
                  button: true,
                  label:
                      context.l10n.diveCenters_accessibility_viewFullscreenMap,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showFullscreenMap(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.fullscreen,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // No map style switcher on the locked preview: the fullscreen map
            // carries one.
          ],
        ),
      ),
    );
  }

  void _showFullscreenMap(BuildContext context, WidgetRef ref) {
    final center = widget.center;
    final colorScheme = Theme.of(context).colorScheme;
    final centerLocation = LatLng(center.latitude!, center.longitude!);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(center.name)),
          body: TrackpadZoomMap(
            controller: _fullController,
            child: FlutterMap(
              mapController: _fullController,
              options: MapOptions(
                initialCenter: centerLocation,
                initialZoom: 14.0,
                minZoom: 2.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                // Its own Consumer: this route is built from the detail
                // page's ref, which would not rebuild the pushed route when
                // the style switcher below changes the map style.
                Consumer(
                  builder: (context, ref, _) => submersionTileLayer(ref),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: centerLocation,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.onPrimary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: DiveCenterMarkerGlyph(
                            logo: center.logo,
                            radius: DiveCenterMarkerGlyph.radiusFor(50),
                            iconColor: colorScheme.onPrimary,
                            iconSize: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const MapAttribution(),
                // No compass: this map does not rotate.
                const Positioned(top: 8, right: 8, child: MapCornerControls()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedNote extends StatelessWidget {
  const _ClosedNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.do_not_disturb_on_outlined, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.l10n.diveCenters_label_permanentlyClosed,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
