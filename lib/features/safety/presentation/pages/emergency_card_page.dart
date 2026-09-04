import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/safety/presentation/widgets/chamber_tile.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
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
    final insurance = diver?.insurance;

    // The diver's own insurer is the first call when they recorded a 24h
    // assistance line: that is who authorizes the evacuation and coordinates
    // the chamber referral, which is the role this card otherwise hands to the
    // regional hotline. Leading with a hotline the diver is not a member of is
    // the complaint in issue #1522.
    //
    // Only the assistance line qualifies. An insurer's office line typically
    // answers in business hours only, so promoting it would promise a first
    // call that rings an empty desk at 2am -- worse than the regional hotline,
    // which does answer. The office line stays in the insurance block below,
    // and the block nudges the diver to record the 24h number.
    final insurerNumber = insurance?.assistanceLine;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (insurerNumber != null) ...[
          _CallAction(
            emphasis: _CallEmphasis.primary,
            label: l10n.emergencyCard_callDan(_insurerName(l10n, insurance!)),
            number: insurerNumber,
            onCall: _call,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emergencyCard_callInsurer_subtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (insurance.policyLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.emergencyCard_insurancePolicy(insurance.policyLabel!),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          _CallAction(
            emphasis: _CallEmphasis.secondary,
            label: l10n.emergencyCard_callDan(data.hotline.name),
            number: data.hotline.phone,
            onCall: _call,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emergencyCard_hotlineSecondary_subtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ] else ...[
          _CallAction(
            emphasis: _CallEmphasis.primary,
            label: l10n.emergencyCard_callDan(data.hotline.name),
            number: data.hotline.phone,
            onCall: _call,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emergencyCard_callDan_subtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
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
        _SectionHeader(title: l10n.emergencyCard_chambersNearby),
        Text(
          l10n.emergencyCard_chambersNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        if (data.nearbyChambers.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.emergencyCard_chambersNoneNearby),
            ),
          )
        else
          for (final listing in data.nearbyChambers)
            ChamberTile(listing: listing, onCall: _call),
        if (data.totalChamberCount > data.nearbyChambers.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.list_alt_outlined),
              label: Text(
                l10n.emergencyCard_chamberViewAll(data.totalChamberCount),
              ),
              onPressed: () => context.push(
                '/settings/diver-profile/emergency-card/chambers',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// What the lead button calls the insurer. A diver can save a number
  /// without naming the provider, and "Call" on its own is not a button.
  String _insurerName(AppLocalizations l10n, DiverInsurance insurance) {
    return insurance.providerLabel ?? l10n.emergencyCard_insuranceSection;
  }
}

/// How loud a call button is. The card has at most one [primary]: two buttons
/// of equal weight is the same "which do I press?" problem under stress as no
/// button at all.
enum _CallEmphasis { primary, secondary }

/// A tap-to-call button showing who answers and the number that will be
/// dialled, so the number stays readable to someone reading it aloud to
/// a bystander rather than tapping it.
class _CallAction extends StatelessWidget {
  final _CallEmphasis emphasis;
  final String label;
  final String number;
  final Future<void> Function(String) onCall;

  const _CallAction({
    required this.emphasis,
    required this.label,
    required this.number,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = emphasis == _CallEmphasis.primary;
    final child = Text('$label\n$number', textAlign: TextAlign.center);
    final icon = Icon(Icons.phone, size: isPrimary ? 28 : 24);

    void handleTap() => onCall(number);

    if (isPrimary) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          textStyle: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: icon,
        label: child,
        onPressed: handleTap,
      );
    }

    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: icon,
      label: child,
      onPressed: handleTap,
    );
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

    Widget insurerNumber({
      required String label,
      required String? number,
      required IconData icon,
    }) {
      // Callers pass the entity's already-normalized getters, so a blank is
      // null by the time it arrives here.
      if (number == null) return const SizedBox.shrink();
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label, style: big),
        subtitle: Text(number),
        trailing: const Icon(Icons.phone, size: 20),
        onTap: () => onCall(number),
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
        if (_hasInsuranceDetails(diver.insurance)) ...[
          const SizedBox(height: 16),
          _SectionHeader(title: l10n.emergencyCard_insuranceSection),
          if (diver.insurance.providerLabel != null)
            Text(diver.insurance.providerLabel!, style: big),
          if (diver.insurance.policyLabel != null)
            Text(
              l10n.emergencyCard_insurancePolicy(diver.insurance.policyLabel!),
              style: big,
            ),
          insurerNumber(
            label: l10n.emergencyCard_insuranceEmergencyLine,
            number: diver.insurance.assistanceLine,
            icon: Icons.emergency_share_outlined,
          ),
          insurerNumber(
            label: l10n.emergencyCard_insuranceOfficeLine,
            number: diver.insurance.officeLine,
            icon: Icons.phone_outlined,
          ),
          // No 24h assistance line is the state issue #1522 describes: the
          // card cannot lead with the insurer, so say why rather than leaving
          // the diver to wonder. An office line alone still lands here, since
          // it is not a number this card will promote.
          if (diver.insurance.assistanceLine == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.emergencyCard_insuranceNoPhone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Whether the insurance block has anything worth a section header. A diver
/// who saved only an assistance number still gets the section.
///
/// Deliberately narrower than [DiverInsurance.hasAnyDetail], which also counts
/// the expiry date: the card does not render an expiry, so keying off it would
/// print a header over an empty block. Persistence and export use the wider
/// one.
bool _hasInsuranceDetails(DiverInsurance insurance) {
  return insurance.providerLabel != null ||
      insurance.policyLabel != null ||
      insurance.hasCallNumber;
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
