import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/agency_color_picker.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Creates a custom agency, or edits [existing], and returns the saved row,
/// or null when cancelled (issue #690). Used by the manage page and by the
/// "Add custom agency..." item in the editors' agency dropdowns.
Future<CustomCertificationAgency?> showCustomAgencyDialog(
  BuildContext context, {
  CustomCertificationAgency? existing,
}) => showDialog<CustomCertificationAgency>(
  context: context,
  builder: (_) => _CustomAgencyDialog(existing: existing),
);

class _CustomAgencyDialog extends ConsumerStatefulWidget {
  const _CustomAgencyDialog({this.existing});

  final CustomCertificationAgency? existing;

  @override
  ConsumerState<_CustomAgencyDialog> createState() =>
      _CustomAgencyDialogState();
}

class _CustomAgencyDialogState extends ConsumerState<_CustomAgencyDialog> {
  late final TextEditingController _name;
  late int _colorArgb;
  bool _isShared = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    // A new agency starts on a colour derived from a fresh id, so a quick
    // create needs no choice; the repository assigns the real id.
    _colorArgb =
        existing?.colorArgb ?? defaultAgencyColorArgb(const Uuid().v4());
    _isShared = existing?.isShared ?? false;
    if (existing == null) {
      ref.read(shareByDefaultProvider.future).then((value) {
        if (mounted) setState(() => _isShared = value);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.certificationAgencies_error_nameRequired);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(customCertificationRepositoryProvider);
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final existing = widget.existing;
      final saved = existing == null
          ? await repo.createAgency(
              diverId: diverId,
              name: _name.text,
              colorArgb: _colorArgb,
              isShared: _isShared,
            )
          : await repo.updateAgency(
              existing.copyWith(
                name: _name.text,
                colorArgb: _colorArgb,
                isShared: _isShared,
              ),
              actingDiverId: diverId,
            );
      if (mounted) Navigator.of(context).pop(saved);
    } on CertificationNameTakenException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.certificationAgencies_error_nameTaken;
      });
    } catch (_) {
      // The repository has logged it; keep the dialog usable so the diver
      // can retry or cancel.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.common_error_tryAgain;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showShare = ref
        .watch(allDiversProvider)
        .maybeWhen(data: (d) => d.length >= 2, orElse: () => false);
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.certificationAgencies_dialog_newAgencyTitle
            : l10n.certificationAgencies_dialog_editAgencyTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.certificationAgencies_dialog_nameLabel,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text(l10n.certificationAgencies_dialog_colorLabel),
            const SizedBox(height: 8),
            AgencyColorPicker(
              selectedArgb: _colorArgb,
              onSelected: (argb) => setState(() => _colorArgb = argb),
            ),
            if (showShare) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.common_label_shareWithAllProfiles),
                value: _isShared,
                onChanged: (v) => setState(() => _isShared = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
