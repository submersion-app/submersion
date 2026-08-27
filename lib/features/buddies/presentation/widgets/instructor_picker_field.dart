import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/certification_primary.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// Dropdown for picking a certification/course instructor from the buddy
/// list. Buddies holding an instructor-level certification (Instructor,
/// Master Instructor, Course Director, etc. -- see
/// [CertificationLevel.isInstructorLevel]) are grouped first and annotated
/// with it; any buddy remains selectable (autofills name only).
class InstructorPickerField extends ConsumerStatefulWidget {
  final String? instructorId;
  final void Function(Buddy? buddy, Certification? instructorCert) onSelected;

  const InstructorPickerField({
    super.key,
    required this.instructorId,
    required this.onSelected,
  });

  @override
  ConsumerState<InstructorPickerField> createState() =>
      _InstructorPickerFieldState();
}

class _InstructorPickerFieldState extends ConsumerState<InstructorPickerField> {
  Map<String, List<Certification>> _certsByBuddy =
      const <String, List<Certification>>{};

  @override
  void initState() {
    super.initState();
    // A manual listener rather than `ref.watch(allBuddyCertificationsProvider)`
    // in build(): this widget also watches allBuddiesProvider directly for
    // the buddy list, and allBuddyCertificationsProvider transitively
    // watches allBuddiesProvider too. Riverpod's TickerMode-driven auto-pause
    // (which pauses `ref.watch` subscriptions while this widget is covered
    // by another route) trips a pausedActiveSubscriptionCount assertion on
    // resume for that diamond dependency. Manual listeners are exempt from
    // auto-pause, sidestepping the bug while staying reactive via setState.
    // Same pattern as BuddyPicker's _BuddySelectionSheetState (buddy_picker.dart).
    ref.listenManual(allBuddyCertificationsProvider, (previous, next) {
      final value = next.value ?? const <String, List<Certification>>{};
      if (mounted) setState(() => _certsByBuddy = value);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final buddiesAsync = ref.watch(allBuddiesProvider);
    final buddies = buddiesAsync.value ?? const <Buddy>[];
    final certsByBuddy = _certsByBuddy;
    if (buddies.isEmpty) return const SizedBox.shrink();

    Certification? instructorCert(String buddyId) {
      final qualifying = (certsByBuddy[buddyId] ?? const <Certification>[])
          .where((c) => c.level?.isInstructorLevel ?? false)
          .toList();
      return primaryCertification(qualifying);
    }

    final credentialed = buddies
        .where((b) => instructorCert(b.id) != null)
        .toList();
    final others = buddies.where((b) => instructorCert(b.id) == null).toList();
    final ordered = [...credentialed, ...others];
    // Guard against a stale instructorId (buddy deleted / not yet synced).
    final validValue = ordered.any((b) => b.id == widget.instructorId)
        ? widget.instructorId
        : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey(validValue),
      initialValue: validValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.buddies_instructorPicker_label,
        prefixIcon: const Icon(Icons.people),
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(context.l10n.buddies_instructorPicker_none),
        ),
        ...ordered.map((buddy) {
          final cert = instructorCert(buddy.id);
          final label = cert == null
              ? buddy.name
              : '${buddy.name} (${_instructorCertLabel(cert)})';
          return DropdownMenuItem(
            value: buddy.id,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (value) {
        if (value == null) {
          widget.onSelected(null, null);
          return;
        }
        final buddy = ordered.firstWhere((b) => b.id == value);
        widget.onSelected(buddy, instructorCert(buddy.id));
      },
    );
  }
}

/// "PADI Instructor #12345" -- agency, level, and card number when present.
String _instructorCertLabel(Certification cert) {
  final number = cert.cardNumber;
  return [
    cert.agency.displayName,
    cert.level!.displayName,
    if (number != null && number.isNotEmpty) '#$number',
  ].join(' ');
}
