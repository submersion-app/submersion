import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_tag_io.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(NfcWriteSheet);

/// A readable name for a tag key left off a small tag.
String tagFieldLabel(AppLocalizations l10n, String key) => switch (key) {
  'n' => l10n.passport_nfc_fieldName,
  'sn' => l10n.passport_nfc_fieldSerial,
  'vi' => attributeLabel(l10n, 'last_visual_inspection'),
  'h' => attributeLabel(l10n, 'last_hydro_test'),
  'oc' => l10n.passport_nfc_fieldO2Clean,
  'vt' => attributeLabel(l10n, 'valve_type'),
  'm' => attributeLabel(l10n, 'tank_material'),
  'wp' => attributeLabel(l10n, 'working_pressure_bar'),
  'v' => attributeLabel(l10n, 'volume_l'),
  _ => key,
};

/// Writes [payload] to an NFC tag (spec 13.3) and reports the tag type, its
/// capacity and which fields fit.
Future<void> showNfcWriteSheet(
  BuildContext context, {
  required CylinderPassportPayload payload,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (_) => NfcWriteSheet(payload: payload),
);

class NfcWriteSheet extends ConsumerStatefulWidget {
  const NfcWriteSheet({super.key, required this.payload});

  /// The full payload, never the label-bounded one: the tag's own capacity
  /// decides what is left off.
  final CylinderPassportPayload payload;

  @override
  ConsumerState<NfcWriteSheet> createState() => _NfcWriteSheetState();
}

class _NfcWriteSheetState extends ConsumerState<NfcWriteSheet> {
  late final NfcTagService _service = ref.read(nfcTagServiceProvider);
  PassportTagWrite? _result;
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_write());
    });
  }

  @override
  void dispose() {
    if (_waiting) unawaited(_service.cancel());
    super.dispose();
  }

  Future<void> _write() async {
    final l10n = context.l10n;
    setState(() {
      _waiting = true;
      _result = null;
    });
    PassportTagWrite result;
    try {
      result = await _service.withTag(
        promptIos: l10n.passport_nfc_holdNear,
        onTag: (tag) => writePassportTo(tag, widget.payload),
      );
    } on NfcSessionCancelled {
      _waiting = false;
      if (mounted) Navigator.of(context).pop();
      return;
    } catch (e, stackTrace) {
      _log.error('NFC write session failed', error: e, stackTrace: stackTrace);
      result = TagWriteFailed(e);
    }
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _result = result;
    });
  }

  void _cancel() {
    _waiting = false;
    unawaited(_service.cancel());
    Navigator.of(context).pop();
  }

  String _tagInfo(AppLocalizations l10n, TagWritten written) {
    final type = friendlyTagType(written.typeLabel);
    return type == null
        ? l10n.passport_nfc_capacity(written.capacity)
        : l10n.passport_nfc_tagInfo(type, written.capacity);
  }

  String _failure(AppLocalizations l10n, PassportTagWrite result) =>
      switch (result) {
        TagNotNdef() => l10n.passport_nfc_notNdef,
        TagReadOnly() => l10n.passport_nfc_readOnly,
        TagTooSmall(:final capacity) => l10n.passport_nfc_tooSmall(capacity),
        TagReadBackMismatch() => l10n.passport_nfc_readBackFailed,
        TagWriteFailed() || TagWritten() => l10n.passport_nfc_writeFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.passport_nfc_write, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          if (result == null) ...[
            const Icon(Icons.nfc, size: 48),
            const SizedBox(height: 12),
            Text(l10n.passport_nfc_holdNear, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cancel,
                child: Text(l10n.common_action_cancel),
              ),
            ),
          ] else if (result case final TagWritten written) ...[
            Icon(
              Icons.check_circle,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.passport_nfc_written,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_tagInfo(l10n, written), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              written.plan.droppedKeys.isEmpty
                  ? l10n.passport_nfc_allFields
                  : l10n.passport_nfc_fieldsDropped(
                      written.plan.droppedKeys
                          .map((k) => tagFieldLabel(l10n, k))
                          .join(', '),
                    ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.common_action_done),
              ),
            ),
          ] else ...[
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_failure(l10n, result), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_close),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _write,
                  child: Text(l10n.passport_nfc_retry),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
