import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/custom_agency_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The agency picker shared by the certification and course editors (issue
/// #690): built-ins, the diver's visible custom agencies, Other, then an
/// action that creates a custom agency and selects it.
class CertificationAgencyDropdown extends ConsumerStatefulWidget {
  const CertificationAgencyDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelText,
    this.isDense = false,
  });

  /// The selected agency id (a built-in enum name or a custom id).
  final String value;
  final ValueChanged<String> onChanged;
  final String labelText;
  final bool isDense;

  @override
  ConsumerState<CertificationAgencyDropdown> createState() =>
      _CertificationAgencyDropdownState();
}

class _CertificationAgencyDropdownState
    extends ConsumerState<CertificationAgencyDropdown> {
  static const _addAction = '__addCustomAgency__';

  /// Bumped to remount the field after the add action, so the action row is
  /// never left showing as the selection when the dialog is cancelled.
  int _revision = 0;

  Future<void> _onChanged(String? value) async {
    if (value == null) return;
    if (value != _addAction) {
      widget.onChanged(value);
      return;
    }
    final created = await showCustomAgencyDialog(context);
    if (!mounted) return;
    setState(() => _revision++);
    if (created != null) widget.onChanged(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(certificationCatalogSyncProvider);
    final l10n = context.l10n;
    final agencies = catalog.agencies;
    final offered = agencies.any((a) => a.id == widget.value);
    return DropdownButtonFormField<String>(
      key: ValueKey('agency-dropdown-$_revision-${widget.value}'),
      initialValue: widget.value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.business),
        isDense: widget.isDense,
      ),
      items: [
        for (final a in agencies)
          DropdownMenuItem(value: a.id, child: Text(a.localizedName(l10n))),
        // A stored agency the pickers do not offer (unknown, or another
        // diver's private one) still has to render.
        if (!offered)
          DropdownMenuItem(
            value: widget.value,
            child: Text(catalog.agency(widget.value).localizedName(l10n)),
          ),
        DropdownMenuItem(
          value: _addAction,
          child: Text(
            l10n.certificationAgencies_addCustomAgency,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
      onChanged: _onChanged,
    );
  }
}
