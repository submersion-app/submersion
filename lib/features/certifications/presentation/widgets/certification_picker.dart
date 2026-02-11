import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// A widget for selecting a certification to link to a course.
class CertificationPicker extends ConsumerWidget {
  final Certification? selectedCertification;
  final ValueChanged<Certification?> onCertificationSelected;

  const CertificationPicker({
    super.key,
    this.selectedCertification,
    required this.onCertificationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: selectedCertification != null
            ? Colors.green.withValues(alpha: 0.15)
            : colorScheme.primaryContainer,
        child: Icon(
          Icons.card_membership,
          color: selectedCertification != null
              ? Colors.green
              : colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        selectedCertification?.name ??
            context.l10n.certifications_picker_noSelection,
      ),
      subtitle: selectedCertification != null
          ? Text(selectedCertification!.agency.displayName)
          : Text(context.l10n.certifications_picker_hint),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCertification != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onCertificationSelected(null),
              tooltip: context.l10n.certifications_picker_clearTooltip,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showCertificationPickerSheet(context, ref),
    );
  }

  void _showCertificationPickerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => CertificationPickerSheet(
          scrollController: scrollController,
          selectedCertification: selectedCertification,
          onCertificationSelected: (cert) {
            Navigator.of(sheetContext).pop();
            onCertificationSelected(cert);
          },
        ),
      ),
    );
  }
}

/// A bottom sheet widget for selecting a certification from a list.
class CertificationPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final Certification? selectedCertification;
  final ValueChanged<Certification> onCertificationSelected;

  const CertificationPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedCertification,
    required this.onCertificationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title and add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.certifications_picker_sheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/certifications/new');
                },
                icon: const Icon(Icons.add),
                label: Text(context.l10n.certifications_picker_newCert),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Certification list
        Expanded(
          child: certificationsAsync.when(
            data: (certifications) {
              if (certifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_membership_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.certifications_picker_empty_title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/certifications/new');
                        },
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.certifications_picker_empty_addButton,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Sort by issue date descending (most recent first)
              final sortedCerts = List<Certification>.from(certifications)
                ..sort((a, b) {
                  final aDate = a.issueDate ?? a.createdAt;
                  final bDate = b.issueDate ?? b.createdAt;
                  return bDate.compareTo(aDate);
                });

              return ListView.builder(
                controller: scrollController,
                itemCount: sortedCerts.length,
                itemBuilder: (context, index) {
                  final cert = sortedCerts[index];
                  final isSelected = selectedCertification?.id == cert.id;
                  final dateFormat = DateFormat.yMMMd();

                  final certLabel = cert.issueDate != null
                      ? '${cert.agency.displayName} ${cert.name}, issued ${dateFormat.format(cert.issueDate!)}${isSelected ? ', selected' : ''}${cert.isExpired ? ', expired' : ''}'
                      : '${cert.agency.displayName} ${cert.name}${isSelected ? ', selected' : ''}${cert.isExpired ? ', expired' : ''}';

                  return Semantics(
                    label: certLabel,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? colorScheme.primary
                            : Colors.green.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.card_membership,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : Colors.green,
                        ),
                      ),
                      title: Text(cert.name),
                      subtitle: Text(
                        cert.issueDate != null
                            ? '${cert.agency.displayName} - ${dateFormat.format(cert.issueDate!)}'
                            : cert.agency.displayName,
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : cert.isExpired
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.l10n.certifications_picker_expired,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                    ),
                              ),
                            )
                          : null,
                      onTap: () => onCertificationSelected(cert),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.certifications_picker_error(error.toString()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
