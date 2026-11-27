import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_card_ids.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_fields.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_align_page.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_correction_card.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_dive_choice.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_equipment_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';

/// The underwater track page's cards that can be edited in place (issue
/// #4527, phase 3, plan 5), by card id. Every card shows its "none" row
/// when it has nothing, so none is ever offered in the strip.
final Map<NavTrackCardId, EditCard<NavTrack>> navTrackEditCards = {
  for (final id in NavTrackCardId.values)
    id: EditCard<NavTrack>(
      id: id.name,
      title: (context) => id.localizedDisplayName(context.l10n),
      isEmpty: (_) => false,
      editorBuilder: (context, session) => switch (id) {
        NavTrackCardId.header => NavTrackHeaderCardEditor(session: session),
        NavTrackCardId.dive => NavTrackDiveCardEditor(session: session),
        NavTrackCardId.site => NavTrackSiteCardEditor(session: session),
        NavTrackCardId.device => NavTrackDeviceCardEditor(session: session),
        NavTrackCardId.correction => NavTrackCorrectionCardEditor(
          session: session,
        ),
      },
    ),
};

/// The header block's editor: the route's own name. Blank falls back to
/// the file it was imported from.
class NavTrackHeaderCardEditor extends StatefulWidget {
  const NavTrackHeaderCardEditor({super.key, required this.session});

  final EditSession<NavTrack> session;

  @override
  State<NavTrackHeaderCardEditor> createState() =>
      _NavTrackHeaderCardEditorState();
}

class _NavTrackHeaderCardEditorState extends State<NavTrackHeaderCardEditor> {
  late final _binding = FieldTextBinding<NavTrack, String?>(
    session: widget.session,
    field: navTrackNameField,
    format: (value) => value ?? '',
    // Any text is a value: blank is no name.
    parse: FieldValue<String?>.new,
  );

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('nav-track-name-field'),
    controller: _binding.controller,
    autofocus: true,
    decoration: InputDecoration(
      hintText:
          widget.session.stored.sourceRef ??
          context.l10n.navTrack_detail_defaultTrackTitle,
    ),
  );
}

/// One editor row: what the card holds now, and its actions below it.
class _EditorRow extends StatelessWidget {
  const _EditorRow({
    required this.icon,
    required this.label,
    required this.actions,
  });

  final IconData icon;
  final String label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: actions),
    ],
  );
}

/// The Dive card's editor: choose or change the dive, or unlink it.
/// Linking, and what it brings with it, is written at Save.
class NavTrackDiveCardEditor extends StatelessWidget {
  const NavTrackDiveCardEditor({super.key, required this.session});

  final EditSession<NavTrack> session;

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final chosen = await chooseNavTrackDive(
      context,
      ref,
      session.stored,
      linkedId: session.valueOf(navTrackDiveField),
    );
    if (chosen != null) session.set(navTrackDiveField, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The providers are watched in a Consumer under the builder, so a dive,
    // site or item the editor no longer shows is no longer watched.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) {
          final diveId = session.valueOf(navTrackDiveField);
          final dive = diveId == null
              ? null
              : ref.watch(diveProvider(diveId)).value;
          return _EditorRow(
            icon: diveId == null ? Icons.link_off : Icons.link,
            label: diveId == null
                ? l10n.navTrack_detail_noDiveLinked
                : navTrackDiveLabel(l10n, diveId, dive),
            actions: [
              OutlinedButton(
                key: const ValueKey('nav-track-edit-choose-dive'),
                onPressed: () => _choose(context, ref),
                child: Text(
                  diveId == null
                      ? l10n.navTrack_detail_chooseDive
                      : l10n.navTrack_detail_menuChangeDive,
                ),
              ),
              if (diveId != null)
                TextButton(
                  key: const ValueKey('nav-track-edit-unlink'),
                  onPressed: () => session.set(navTrackDiveField, null),
                  child: Text(l10n.navTrack_common_unlink),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The Site card's editor: change the site through the site picker, which
/// can create one. The anchor follows the new site's pin as it always has.
class NavTrackSiteCardEditor extends StatelessWidget {
  const NavTrackSiteCardEditor({super.key, required this.session});

  final EditSession<NavTrack> session;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final oldSiteId = session.valueOf(navTrackSiteField);
    final oldSiteLocation = oldSiteId == null
        ? null
        : (await ref.read(siteProvider(oldSiteId).future))?.location;
    if (!context.mounted) return;
    final site = await pickOrCreateSite(
      context,
      ref,
      selectedSiteId: oldSiteId,
      newSiteSeedLocation: session.valueOf(navTrackAnchorField),
    );
    if (site == null) return;
    pickNavTrackSite(session, site, oldSiteLocation: oldSiteLocation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The providers are watched in a Consumer under the builder, so a dive,
    // site or item the editor no longer shows is no longer watched.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) {
          final siteId = session.valueOf(navTrackSiteField);
          final name = siteId == null
              ? null
              : ref.watch(siteProvider(siteId)).value?.name;
          return _EditorRow(
            icon: Icons.place_outlined,
            label: name ?? l10n.navTrack_detail_noSite,
            actions: [
              OutlinedButton(
                key: const ValueKey('nav-track-edit-change-site'),
                onPressed: () => _change(context, ref),
                child: Text(
                  siteId == null
                      ? l10n.navTrack_detail_chooseSite
                      : l10n.navTrack_detail_menuChangeSite,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The Device card's editor: choose an equipment item, or clear both the
/// item and the device name.
class NavTrackDeviceCardEditor extends StatelessWidget {
  const NavTrackDeviceCardEditor({super.key, required this.session});

  final EditSession<NavTrack> session;

  Future<void> _change(BuildContext context) async {
    final choice = await pickNavTrackEquipment(
      context,
      selectedEquipmentId: session.valueOf(navTrackDeviceField).equipmentId,
    );
    switch (choice) {
      case NavTrackEquipmentChosen(:final item):
        session.set(navTrackDeviceField, (
          equipmentId: item.id,
          deviceName: item.name,
        ));
      case NavTrackEquipmentCleared():
        session.set(navTrackDeviceField, (equipmentId: null, deviceName: null));
      case NavTrackEquipmentPickCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The providers are watched in a Consumer under the builder, so a dive,
    // site or item the editor no longer shows is no longer watched.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) {
          final device = session.valueOf(navTrackDeviceField);
          final equipmentId = device.equipmentId;
          final itemName = equipmentId == null
              ? null
              : ref.watch(equipmentItemProvider(equipmentId)).value?.name;
          final hasDevice = equipmentId != null || device.deviceName != null;
          return _EditorRow(
            icon: Icons.directions_boat_filled_outlined,
            label:
                itemName ??
                device.deviceName ??
                l10n.navTrack_detail_noEquipment,
            actions: [
              OutlinedButton(
                key: const ValueKey('nav-track-edit-change-device'),
                onPressed: () => _change(context),
                child: Text(
                  hasDevice
                      ? l10n.navTrack_detail_menuChangeDevice
                      : l10n.navTrack_detail_chooseDevice,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The Correction card's editor: what is corrected, and the align page,
/// which joins this sitting and hands its correction back with Done.
class NavTrackCorrectionCardEditor extends StatelessWidget {
  const NavTrackCorrectionCardEditor({super.key, required this.session});

  final EditSession<NavTrack> session;

  @override
  Widget build(BuildContext context) {
    void align() => pushRecordSatellite<NavTrack, void>(
      context,
      builder: (joined) =>
          NavTrackAlignPage(routeId: session.stored.id, joinedSitting: joined),
    );
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) =>
          NavTrackCorrectionCard(route: session.working, onOpen: align),
    );
  }
}
