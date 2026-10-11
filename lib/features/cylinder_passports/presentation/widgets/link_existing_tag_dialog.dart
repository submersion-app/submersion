import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The passport id of a cylinder tag link, or null for anything else.
String? cylinderPassportIdOf(String text) =>
    switch (PassportPayloadCodec.decode(text)) {
      PassportDecoded(:final payload) => payload.passportId,
      PassportRejected() => null,
    };

/// Paste a tag's link to give this item that tag's passport id, so labels
/// already on the gear keep working after a row was re-created (spec
/// section 6.5). [passportIdOf] reads the kind of tag this item takes:
/// cylinder links by default, either kind for other gear (issue
/// #2652). Resolves with the linked passport id, or null.
Future<String?> showLinkExistingTagDialog(
  BuildContext context, {
  required String equipmentId,
  String? diverId,
  String? Function(String text) passportIdOf = cylinderPassportIdOf,
  String Function(AppLocalizations l10n)? invalidText,
}) => showDialog<String>(
  context: context,
  builder: (context) => _LinkExistingTagDialog(
    equipmentId: equipmentId,
    diverId: diverId,
    passportIdOf: passportIdOf,
    invalidText: invalidText,
  ),
);

class _LinkExistingTagDialog extends ConsumerStatefulWidget {
  const _LinkExistingTagDialog({
    required this.equipmentId,
    this.diverId,
    required this.passportIdOf,
    this.invalidText,
  });

  final String equipmentId;
  final String? diverId;
  final String? Function(String text) passportIdOf;

  /// What a link [passportIdOf] refuses is called; the cylinder wording
  /// when null.
  final String Function(AppLocalizations l10n)? invalidText;

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
    final passportId = widget.passportIdOf(_controller.text);
    if (passportId == null) {
      setState(
        () => _error =
            widget.invalidText?.call(l10n) ?? l10n.passport_tag_linkInvalid,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(cylinderPassportRepositoryProvider)
          .assignPassportId(
            equipmentId: widget.equipmentId,
            passportId: passportId,
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
    Navigator.of(context).pop(passportId);
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
