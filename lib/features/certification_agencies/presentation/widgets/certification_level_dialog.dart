import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Creates a custom certification under [agencyId], or edits [existing],
/// and returns the saved row, or null when cancelled (issue #690).
Future<CustomCertificationLevel?> showCertificationLevelDialog(
  BuildContext context, {
  required String agencyId,
  CustomCertificationLevel? existing,
}) => showDialog<CustomCertificationLevel>(
  context: context,
  builder: (_) =>
      _CertificationLevelDialog(agencyId: agencyId, existing: existing),
);

class _CertificationLevelDialog extends ConsumerStatefulWidget {
  const _CertificationLevelDialog({required this.agencyId, this.existing});

  final String agencyId;
  final CustomCertificationLevel? existing;

  @override
  ConsumerState<_CertificationLevelDialog> createState() =>
      _CertificationLevelDialogState();
}

class _CertificationLevelDialogState
    extends ConsumerState<_CertificationLevelDialog> {
  late final TextEditingController _name;
  late bool _isProgression;
  bool _isShared = false;
  String? _error;
  bool _saving = false;

  /// Only a level under a built-in agency carries its own share flag; one
  /// under a custom agency follows the agency.
  bool get _ownShareFlag => CertificationAgency.fromId(widget.agencyId) != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _isProgression = existing?.isProgression ?? true;
    _isShared = existing?.isShared ?? false;
    if (existing == null && _ownShareFlag) {
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
          ? await repo.createLevel(
              diverId: diverId,
              agencyId: widget.agencyId,
              name: _name.text,
              isProgression: _isProgression,
              isShared: _isShared,
            )
          : await repo.updateLevel(
              existing.copyWith(
                name: _name.text,
                isProgression: _isProgression,
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
    final showShare =
        _ownShareFlag &&
        ref
            .watch(allDiversProvider)
            .maybeWhen(data: (d) => d.length >= 2, orElse: () => false);
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.certificationAgencies_dialog_newCertificationTitle
            : l10n.certificationAgencies_dialog_editCertificationTitle,
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
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(l10n.certifications_edit_group_progression),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(l10n.certificationAgencies_dialog_specialty),
                ),
              ],
              selected: {_isProgression},
              onSelectionChanged: (s) =>
                  setState(() => _isProgression = s.first),
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
