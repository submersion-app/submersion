import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_owner_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Filed under": the record a document belongs to. Tapping asks for
/// another; a certification card is locked to its certification.
class DocumentOwnerField extends ConsumerWidget {
  final DocumentOwner owner;
  final bool locked;
  final VoidCallback onTap;

  const DocumentOwnerField({
    super.key = const ValueKey('document-owner-field'),
    required this.owner,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = owner.isPersonal
        ? null
        : owner.kind == DocumentOwnerKind.certification
        ? _certificationTitle(ref, l10n)
        : ref.watch(documentOwnerLabelProvider(owner)).value;
    // The record's name, its kind shown by the icon; the kind's own label
    // only when there is no name (Personal, or an unnumbered dive).
    final text = name == null || name.isEmpty
        ? documentOwnerKindLabel(l10n, owner.kind)
        : name;
    // Announced as a button: the field reads as text, but tapping it is
    // how a document is refiled.
    return Semantics(
      button: true,
      enabled: !locked,
      child: InkWell(
        onTap: locked ? null : onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.documents_detail_owner,
            prefixIcon: Icon(documentOwnerKindIcon(owner.kind)),
            helperText: locked ? l10n.documents_owner_locked : null,
            suffixIcon: Icon(
              locked ? Icons.lock_outline : Icons.arrow_drop_down,
            ),
          ),
          child: Text(text),
        ),
      ),
    );
  }

  /// The owning certification's title as the Certifications screens show
  /// it: its stored name is empty when it has no custom title (#3366).
  String? _certificationTitle(WidgetRef ref, AppLocalizations l10n) {
    final id = owner.id;
    if (id == null) return null;
    final fields = ref.watch(documentOwnerCertificationProvider(id)).value;
    return fields == null
        ? null
        : certificationTitleFieldsL10n(
            fields,
            l10n,
            catalog: ref.watch(certificationCatalogSyncProvider),
          );
  }
}
