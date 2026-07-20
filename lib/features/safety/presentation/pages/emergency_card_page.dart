import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The offline emergency card: one screen readable by a stranger under
/// stress. Large type, tap-to-call, everything sourced locally.
class EmergencyCardPage extends ConsumerWidget {
  const EmergencyCardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dataAsync = ref.watch(emergencyCardDataProvider);

    // A new chamber is stamped with the active diver id; with no diver profile
    // loaded it would create a null-diver (global) row, so gate the action.
    final canAddChamber = dataAsync.value?.diver != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.emergencyCard_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: l10n.emergencyCard_addChamber,
            onPressed: canAddChamber
                ? () => context.push(
                    '/settings/diver-profile/emergency-card/add-chamber',
                  )
                : null,
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.common_error_tryAgain,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) => _CardBody(data: data),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  final EmergencyCardData data;

  const _CardBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final diver = data.diver;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Call DAN: always first and biggest.
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            textStyle: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          icon: const Icon(Icons.phone, size: 28),
          label: Text(
            '${l10n.emergencyCard_callDan(data.hotline.name)}\n'
            '${data.hotline.phone}',
            textAlign: TextAlign.center,
          ),
          onPressed: () => _call(data.hotline.phone),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.emergencyCard_callDan_subtitle,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          data.countryCode != null
              ? l10n.emergencyCard_regionLabel(data.countryCode!)
              : l10n.emergencyCard_regionUnknown,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: theme.textTheme.titleMedium,
          ),
          icon: const Icon(Icons.local_hospital_outlined),
          label: Text(l10n.emergencyCard_ems(data.emsNumber)),
          onPressed: () => _call(data.emsNumber),
        ),
        const SizedBox(height: 24),
        if (diver != null) ...[
          _DiverSection(diver: diver, onCall: _call),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.emergencyCard_noDiverData),
            ),
          ),
        const SizedBox(height: 24),
        _SectionHeader(title: l10n.emergencyCard_chambersSection),
        Text(
          l10n.emergencyCard_chambersNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        for (final chamber in data.chambers)
          _ChamberTile(chamber: chamber, onCall: _call),
      ],
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _DiverSection extends StatelessWidget {
  final Diver diver;
  final Future<void> Function(String) onCall;

  const _DiverSection({required this.diver, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final big = theme.textTheme.titleMedium;

    Widget contact(EmergencyContact c) {
      if (!c.isComplete) return const SizedBox.shrink();
      return ListTile(
        dense: false,
        leading: const Icon(Icons.person_outline),
        title: Text(
          '${c.name}${c.relation != null ? ' (${c.relation})' : ''}',
          style: big,
        ),
        subtitle: Text(c.phone ?? ''),
        trailing: const Icon(Icons.phone, size: 20),
        onTap: c.phone != null ? () => onCall(c.phone!) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.emergencyCard_diverSection),
        Text(diver.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        if (diver.bloodType != null && diver.bloodType!.isNotEmpty)
          Text(l10n.emergencyCard_bloodType(diver.bloodType!), style: big),
        if (diver.allergies != null && diver.allergies!.isNotEmpty)
          Text(l10n.emergencyCard_allergies(diver.allergies!), style: big),
        if (diver.medications != null && diver.medications!.isNotEmpty)
          Text(l10n.emergencyCard_medications(diver.medications!), style: big),
        if (diver.medicalNotes.isNotEmpty)
          Text(diver.medicalNotes, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        _SectionHeader(title: l10n.emergencyCard_contactsSection),
        contact(diver.emergencyContact),
        contact(diver.emergencyContact2),
        if (diver.insurance.provider != null &&
            diver.insurance.provider!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: l10n.emergencyCard_insuranceSection),
          Text(diver.insurance.provider!, style: big),
          if (diver.insurance.policyNumber != null)
            Text(
              l10n.emergencyCard_insurancePolicy(diver.insurance.policyNumber!),
              style: big,
            ),
        ],
      ],
    );
  }
}

class _ChamberTile extends ConsumerWidget {
  final EmergencyChamber chamber;
  final Future<void> Function(String) onCall;

  const _ChamberTile({required this.chamber, required this.onCall});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final subtitle = [
      if (chamber.city != null) chamber.city!,
      chamber.country,
      chamber.phone,
      if (chamber.lastVerified != null)
        l10n.emergencyCard_chamberVerified(
          DateFormat.yMMM().format(chamber.lastVerified!),
        ),
    ].join(' - ');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.medical_services_outlined),
        title: Text(chamber.name, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'hide') {
              // Capture the messenger before the await; hiding a bundled
              // chamber is otherwise irreversible from this screen, so offer
              // an immediate undo.
              final messenger = ScaffoldMessenger.of(context);
              final notifier = ref.read(settingsProvider.notifier);
              await notifier.setChamberHidden(chamber.id, true);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.emergencyCard_chamberHidden),
                  action: SnackBarAction(
                    label: l10n.emergencyCard_undo,
                    onPressed: () =>
                        notifier.setChamberHidden(chamber.id, false),
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
        ),
        onTap: () => onCall(chamber.phone),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
