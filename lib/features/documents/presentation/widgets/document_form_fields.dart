import 'package:flutter/material.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lead times offered for the expiry reminder; 0 turns it off.
const List<int> kDocumentReminderLeadChoices = [0, 7, 14, 30, 60, 90];

/// The text controllers the document editor owns.
class DocumentFormControllers {
  final title = TextEditingController();
  final issuer = TextEditingController();
  final number = TextEditingController();
  final emergencyPhone = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();

  List<TextEditingController> get all => [
    title,
    issuer,
    number,
    emergencyPhone,
    phone,
    notes,
  ];

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}

/// The editor's fields for [type]. Insurance adds its phones and the
/// primary toggle; a certification card has no expiry or reminder (its
/// expiry lives on the certification).
class DocumentFormFields extends StatelessWidget {
  final DocumentType type;
  final List<DocumentType> typeChoices;
  final DocumentFormControllers controllers;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final int reminderLeadDays;
  final bool isPrimary;
  final String Function(DateTime date) formatDate;
  final ValueChanged<DocumentType> onTypeChanged;
  final VoidCallback onPickIssueDate;
  final VoidCallback onPickExpiryDate;
  final VoidCallback onClearIssueDate;
  final VoidCallback onClearExpiryDate;
  final ValueChanged<int> onLeadChanged;
  final ValueChanged<bool> onPrimaryChanged;

  const DocumentFormFields({
    super.key,
    required this.type,
    required this.typeChoices,
    required this.controllers,
    required this.issueDate,
    required this.expiryDate,
    required this.reminderLeadDays,
    required this.isPrimary,
    required this.formatDate,
    required this.onTypeChanged,
    required this.onPickIssueDate,
    required this.onPickExpiryDate,
    required this.onClearIssueDate,
    required this.onClearExpiryDate,
    required this.onLeadChanged,
    required this.onPrimaryChanged,
  });

  bool get _insurance => type == DocumentType.insurance;
  bool get _card => type == DocumentType.certificationCard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<DocumentType>(
          key: const Key('document-type'),
          initialValue: type,
          decoration: InputDecoration(labelText: l10n.documents_field_type),
          items: [
            for (final t in typeChoices)
              DropdownMenuItem(
                value: t,
                child: Row(
                  children: [
                    Icon(documentTypeIcon(t), size: 18),
                    const SizedBox(width: 8),
                    Text(documentTypeLabel(l10n, t)),
                  ],
                ),
              ),
          ],
          onChanged: typeChoices.length < 2
              ? null
              : (t) {
                  if (t != null) onTypeChanged(t);
                },
        ),
        // A card is titled by its certification, so it has no title of
        // its own to edit.
        if (!_card) ...[
          gap,
          TextFormField(
            key: const Key('document-title'),
            controller: controllers.title,
            decoration: InputDecoration(
              labelText: l10n.documents_field_title,
              hintText: documentTypeLabel(l10n, type),
            ),
          ),
        ],
        gap,
        TextFormField(
          controller: controllers.issuer,
          decoration: InputDecoration(
            labelText: _insurance
                ? l10n.documents_field_issuerInsurance
                : l10n.documents_field_issuer,
          ),
        ),
        gap,
        TextFormField(
          controller: controllers.number,
          decoration: InputDecoration(
            labelText: _insurance
                ? l10n.documents_field_referenceNumberInsurance
                : l10n.documents_field_referenceNumber,
          ),
        ),
        if (_insurance) ...[
          gap,
          TextFormField(
            controller: controllers.emergencyPhone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.documents_field_emergencyPhone,
            ),
          ),
          gap,
          TextFormField(
            controller: controllers.phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.documents_field_phone),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.documents_field_isPrimary),
            subtitle: Text(l10n.documents_field_isPrimary_subtitle),
            value: isPrimary,
            onChanged: onPrimaryChanged,
          ),
        ],
        _DateRow(
          label: l10n.documents_field_issueDate,
          value: issueDate,
          formatDate: formatDate,
          onPick: onPickIssueDate,
          onClear: onClearIssueDate,
        ),
        if (!_card) ...[
          _DateRow(
            label: l10n.documents_field_expiryDate,
            value: expiryDate,
            formatDate: formatDate,
            onPick: onPickExpiryDate,
            onClear: onClearExpiryDate,
          ),
          if (expiryDate != null)
            DropdownButtonFormField<int>(
              key: const Key('document-reminder'),
              initialValue:
                  kDocumentReminderLeadChoices.contains(reminderLeadDays)
                  ? reminderLeadDays
                  : null,
              decoration: InputDecoration(
                labelText: l10n.documents_field_reminderLead,
              ),
              items: [
                for (final days in kDocumentReminderLeadChoices)
                  DropdownMenuItem(
                    value: days,
                    child: Text(l10n.documents_field_reminderLeadDays(days)),
                  ),
              ],
              onChanged: (d) {
                if (d != null) onLeadChanged(d);
              },
            ),
        ],
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String Function(DateTime date) formatDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateRow({
    required this.label,
    required this.value,
    required this.formatDate,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final date = value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: date == null ? null : Text(formatDate(date)),
      onTap: onPick,
      trailing: date == null
          ? null
          : IconButton(
              icon: const Icon(Icons.clear),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onClear,
            ),
    );
  }
}
