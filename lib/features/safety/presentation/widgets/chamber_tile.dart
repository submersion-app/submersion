import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/safety/domain/entities/chamber_listing.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One chamber, on the emergency card and in the directory.
///
/// Tapping dials the facility. The capability label carries real weight here:
/// an elective therapy clinic will turn away a bent diver out of hours, so it
/// is styled in the error colour rather than left to look like any other
/// entry.
class ChamberTile extends ConsumerWidget {
  final ChamberListing listing;
  final Future<void> Function(String) onCall;

  /// The hide and delete actions belong to the emergency card, where the diver
  /// curates what they see. The directory is a reference view.
  final bool showActions;

  const ChamberTile({
    super.key,
    required this.listing,
    required this.onCall,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chamber = listing.chamber;
    final units = UnitFormatter(ref.watch(settingsProvider));

    final distance = listing.distanceMeters;
    final where = [
      if (distance != null && distance.isFinite)
        units.formatGeoDistance(distance),
      if (chamber.city != null) chamber.city!,
      chamber.country,
      chamber.callNumber,
    ].join(' - ');

    final provenance = [
      if (chamber.lastVerified != null)
        l10n.emergencyCard_chamberVerified(
          DateFormat.yMMM().format(chamber.lastVerified!),
        ),
      if (chamber.verifiedVia == ChamberVerification.registry)
        l10n.emergencyCard_chamberUnverified,
    ].join(' - ');

    final isElective = chamber.capability == ChamberCapability.elective;
    // Empty for an unknown availability, which is the single place that decides
    // whether the label is worth showing.
    final availability = _availabilityLabel(l10n, chamber.availability);

    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: const Icon(Icons.medical_services_outlined),
        title: Text(chamber.name, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(where),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (chamber.isBuiltIn)
                  _CapabilityLabel(
                    text: _capabilityLabel(l10n, chamber.capability),
                    emphasized: isElective,
                  ),
                if (availability.isNotEmpty)
                  Text(availability, style: theme.textTheme.labelMedium),
              ],
            ),
            if (provenance.isNotEmpty)
              Text(provenance, style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: showActions
            ? _ChamberMenu(chamber: chamber)
            : const Icon(Icons.phone_outlined),
        onTap: () => onCall(chamber.callNumber),
      ),
    );
  }
}

String _capabilityLabel(AppLocalizations l10n, ChamberCapability capability) {
  return switch (capability) {
    ChamberCapability.divingEmergency =>
      l10n.emergencyCard_chamberCapability_divingEmergency,
    ChamberCapability.hyperbaricUnit =>
      l10n.emergencyCard_chamberCapability_hyperbaricUnit,
    ChamberCapability.elective => l10n.emergencyCard_chamberCapability_elective,
    ChamberCapability.unknown => l10n.emergencyCard_chamberCapability_unknown,
  };
}

String _availabilityLabel(
  AppLocalizations l10n,
  ChamberAvailability availability,
) {
  return switch (availability) {
    ChamberAvailability.h24 => l10n.emergencyCard_chamberAvailability_h24,
    ChamberAvailability.onCall => l10n.emergencyCard_chamberAvailability_onCall,
    ChamberAvailability.businessHours =>
      l10n.emergencyCard_chamberAvailability_businessHours,
    ChamberAvailability.unknown => '',
  };
}

class _CapabilityLabel extends StatelessWidget {
  final String text;
  final bool emphasized;

  const _CapabilityLabel({required this.text, required this.emphasized});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized
            ? colors.errorContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: emphasized ? colors.onErrorContainer : colors.onSurfaceVariant,
          fontWeight: emphasized ? FontWeight.bold : null,
        ),
      ),
    );
  }
}

class _ChamberMenu extends ConsumerWidget {
  final EmergencyChamber chamber;

  const _ChamberMenu({required this.chamber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'hide') {
          // Capture the messenger before the await; hiding a bundled chamber
          // is otherwise irreversible from this screen, so offer an immediate
          // undo.
          final messenger = ScaffoldMessenger.of(context);
          final notifier = ref.read(settingsProvider.notifier);
          await notifier.setChamberHidden(chamber.id, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.emergencyCard_chamberHidden),
              action: SnackBarAction(
                label: l10n.emergencyCard_undo,
                onPressed: () => notifier.setChamberHidden(chamber.id, false),
              ),
            ),
          );
        } else if (value == 'delete') {
          await ref
              .read(emergencyChamberRepositoryProvider)
              .deleteChamber(chamber.id);
        }
      },
      itemBuilder: (context) => [
        if (chamber.isBuiltIn)
          PopupMenuItem(
            value: 'hide',
            child: Text(l10n.emergencyCard_hideChamber),
          )
        else
          PopupMenuItem(
            value: 'delete',
            child: Text(l10n.emergencyCard_deleteChamber),
          ),
      ],
    );
  }
}
