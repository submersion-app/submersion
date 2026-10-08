import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Paste a tag's link to give this cylinder that tag's passport id, so labels
/// already on the metal keep working after a row was re-created (spec
/// section 6.5). Resolves with the tag's payload once linked, or null.
Future<CylinderPassportPayload?> showLinkExistingTagDialog(
  BuildContext context, {
  required String equipmentId,
  String? diverId,
}) => showDialog<CylinderPassportPayload>(
  context: context,
  builder: (context) =>
      _LinkExistingTagDialog(equipmentId: equipmentId, diverId: diverId),
);

class _LinkExistingTagDialog extends ConsumerStatefulWidget {
  const _LinkExistingTagDialog({required this.equipmentId, this.diverId});

  final String equipmentId;
  final String? diverId;

  @override
  ConsumerState<_LinkExistingTagDialog> createState() =>
      _LinkExistingTagDialogState();
}

class _LinkExistingTagDialogState
    extends ConsumerState<_LinkExistingTagDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final l10n = context.l10n;
    final result = PassportPayloadCodec.decode(_controller.text);
    if (result is! PassportDecoded) {
      setState(() => _error = l10n.passport_tag_linkInvalid);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(cylinderPassportRepositoryProvider)
          .assignPassportId(
            equipmentId: widget.equipmentId,
            passportId: result.payload.passportId,
            diverId: widget.diverId,
          );
    } on PassportIdInUse catch (e) {
      final holder = await ref
          .read(equipmentRepositoryProvider)
          .getEquipmentById(e.equipmentId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.passport_tag_linkInUse(holder?.name ?? e.equipmentId);
      });
      return;
    } catch (_) {
      // Anything else (a locked database, a row deleted underneath) must not
      // leave the dialog disabled with no word of what happened.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.passport_tag_linkFailed;
      });
      return;
    }
    ref.invalidate(passportIdProvider(widget.equipmentId));
    ref.invalidate(fillsForEquipmentProvider(widget.equipmentId));
    if (!mounted) return;
    Navigator.of(context).pop(result.payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.passport_tag_linkExisting),
      content: TextField(
        key: const Key('linkTag_input'),
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: l10n.passport_tag_linkPrompt,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.forms_cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _link,
          child: Text(l10n.passport_tag_linkExisting),
        ),
      ],
    );
  }
}
