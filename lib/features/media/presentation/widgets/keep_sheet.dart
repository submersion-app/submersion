import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where to keep a file from the Identify viewer, and whether to keep every
/// file not kept yet or only the one on screen (issue #5122).
typedef KeepChoice = ({MediaAttachTarget target, bool all});

/// Asks where to keep: on a dive, on a site, or with no place. With more
/// than one file not kept, it also asks whether to keep this one or all.
/// Null when the diver backs out.
Future<KeepChoice?> showKeepSheet(
  BuildContext context, {
  required int unkeptCount,
}) => showModalBottomSheet<KeepChoice>(
  context: context,
  useSafeArea: true,
  builder: (_) => _KeepSheet(unkeptCount: unkeptCount),
);

class _KeepSheet extends StatefulWidget {
  const _KeepSheet({required this.unkeptCount});

  final int unkeptCount;

  @override
  State<_KeepSheet> createState() => _KeepSheetState();
}

class _KeepSheetState extends State<_KeepSheet> {
  bool _all = false;

  void _done(MediaAttachTarget target) =>
      Navigator.of(context).pop<KeepChoice>((target: target, all: _all));

  Future<void> _onDive() async {
    final diveId = await showDivePickerSheet(context);
    if (diveId != null && mounted) _done(DiveAttachTarget(diveId));
  }

  Future<void> _onSite() async {
    final result = await showSitePicker(context, useDeviceLocation: false);
    if (result is SitePicked && mounted) {
      _done(SiteAttachTarget(result.site.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            l10n.media_identify_keepTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (widget.unkeptCount > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SegmentedButton<bool>(
              key: const ValueKey('media_identify_keep_scope'),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.media_identify_keepThis),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.media_identify_keepAll),
                ),
              ],
              selected: {_all},
              onSelectionChanged: (s) => setState(() => _all = s.single),
            ),
          ),
        ListTile(
          key: const ValueKey('media_identify_keep_dive'),
          leading: const Icon(Icons.scuba_diving),
          title: Text(l10n.media_identify_keepOnDive),
          onTap: _onDive,
        ),
        ListTile(
          key: const ValueKey('media_identify_keep_site'),
          leading: const Icon(Icons.place_outlined),
          title: Text(l10n.media_identify_keepOnSite),
          onTap: _onSite,
        ),
        ListTile(
          key: const ValueKey('media_identify_keep_unplaced'),
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(l10n.media_identify_keepUnplaced),
          onTap: () => _done(const UnplacedAttachTarget()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
