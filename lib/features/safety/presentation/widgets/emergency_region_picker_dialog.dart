import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/safety/domain/constants/emergency_country_names.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver picked: a country code, or null for automatic (the
/// country of the most recent dive). The dialog itself pops null on cancel,
/// which is why the choice is wrapped.
class EmergencyRegionChoice {
  const EmergencyRegionChoice(this.countryCode);

  final String? countryCode;
}

/// Picks the emergency card's region override (issue #3091): "Automatic"
/// first, then every country in [choices] by name, filtered by a search
/// that matches the name or the ISO code.
class EmergencyRegionPickerDialog extends StatefulWidget {
  const EmergencyRegionPickerDialog({
    super.key,
    required this.choices,
    required this.selected,
  });

  /// ISO codes to offer.
  final List<String> choices;

  /// The current override, or null when the region is automatic.
  final String? selected;

  @override
  State<EmergencyRegionPickerDialog> createState() =>
      _EmergencyRegionPickerDialogState();
}

class _EmergencyRegionPickerDialogState
    extends State<EmergencyRegionPickerDialog> {
  String _query = '';

  late final List<String> _byName = [...widget.choices]
    ..sort(
      (a, b) => emergencyRegionDisplayName(
        a,
      ).compareTo(emergencyRegionDisplayName(b)),
    );

  List<String> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _byName;
    return [
      for (final code in _byName)
        if (code.toLowerCase() == query ||
            emergencyRegionDisplayName(code).toLowerCase().contains(query))
          code,
    ];
  }

  void _pick(String? code) =>
      Navigator.of(context).pop(EmergencyRegionChoice(code));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = _visible;

    return AlertDialog(
      title: Text(l10n.emergencyCard_regionPicker_title),
      contentPadding: const EdgeInsets.only(top: 16),
      content: SizedBox(
        width: 400,
        // Short of 480 on a small or landscape screen, so the dialog's
        // actions stay on screen.
        height: math.min(480, MediaQuery.sizeOf(context).height * 0.6),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.emergencyCard_regionPicker_search,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  _tile(
                    label: l10n.emergencyCard_regionPicker_automatic,
                    selected: widget.selected == null,
                    onTap: () => _pick(null),
                  ),
                  const Divider(height: 1),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.emergencyCard_regionPicker_noMatches,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final code in visible)
                    _tile(
                      label: emergencyRegionDisplayName(code),
                      selected: widget.selected == code,
                      onTap: () => _pick(code),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
      ],
    );
  }

  Widget _tile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(label),
      selected: selected,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
