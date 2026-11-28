import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/nfc_availability_text.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/emergency_tag/data/services/emergency_card_pdf_service.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/presentation/providers/emergency_tag_providers.dart';
import 'package:submersion/features/emergency_tag/presentation/utils/emergency_tag_draft.dart';
import 'package:submersion/features/emergency_tag/presentation/utils/emergency_tag_l10n.dart';
import 'package:submersion/features/emergency_tag/presentation/widgets/emergency_tag_sections.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Hands the finished card on: the PDF share sheet in the app, a capture in
/// tests.
typedef EmergencyCardExport =
    Future<void> Function(
      EmergencyCardContent content,
      Rect? origin,
      PdfLocalization localization,
    );

Future<void> _shareCardPdf(
  EmergencyCardContent content,
  Rect? origin,
  PdfLocalization localization,
) => EmergencyCardPdfService().exportToPdf(
  content,
  sharePositionOrigin: origin,
  localization: localization,
);

/// Stores the diver's choices: on their diver row in the app, a capture in
/// tests.
typedef EmergencyTagSave =
    Future<void> Function(WidgetRef ref, EmergencyTagChoices choices);

/// Puts the diver's emergency details on an NFC tag or a printed card
/// (issue #5060).
class EmergencyTagPage extends ConsumerWidget {
  const EmergencyTagPage({
    super.key,
    this.export = _shareCardPdf,
    this.save = saveMyEmergencyTagChoices,
  });

  final EmergencyCardExport export;
  final EmergencyTagSave save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diver = ref.watch(currentDiverProvider);
    final choices = ref.watch(myEmergencyTagChoicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.emergencyTag_title)),
      body: switch ((diver, choices)) {
        (AsyncData(value: final d?), AsyncData(value: final c)) =>
          _EmergencyTagBody(diver: d, stored: c, export: export, save: save),
        (AsyncData(value: null), _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.emergencyCard_noDiverData,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        (AsyncError(), _) ||
        (_, AsyncError()) => Center(child: Text(l10n.common_error_tryAgain)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EmergencyTagBody extends ConsumerStatefulWidget {
  const _EmergencyTagBody({
    required this.diver,
    required this.stored,
    required this.export,
    required this.save,
  });

  final Diver diver;
  final EmergencyTagChoices stored;
  final EmergencyCardExport export;
  final EmergencyTagSave save;

  @override
  ConsumerState<_EmergencyTagBody> createState() => _EmergencyTagBodyState();
}

class _EmergencyTagBodyState extends ConsumerState<_EmergencyTagBody> {
  /// The diver's latest choices, ahead of the save that stores them, so a
  /// switch answers at once.
  late EmergencyTagChoices _choices = widget.stored;

  void _change(EmergencyTagChoices next) {
    setState(() => _choices = next);
    unawaited(widget.save(ref, next));
  }

  EmergencyTagDraft _draft() {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    return EmergencyTagDraft.of(
      widget.diver,
      _choices,
      written: DateTime.now(),
      labels: emergencyTagLabels(l10n, units.formatDate),
      languageCode: l10n.localeName.split('_').first,
    );
  }

  Future<void> _print(BuildContext anchor, EmergencyTagDraft draft) async {
    final l10n = context.l10n;
    final box = anchor.findRenderObject() as RenderBox?;
    await widget.export(
      EmergencyCardContent(
        lines: draft.text.split('\n'),
        qrData: draft.firstUri,
        qrCaption: draft.callUri == null
            ? l10n.emergencyTag_card_qrLink
            : l10n.emergencyTag_card_qrCall,
      ),
      box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      PdfLocalization.forLanguageCode(l10n.localeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final draft = _draft();
    final nfcPresent =
        ref.watch(deviceCapabilitiesProvider).nfc && nfcPlatform();
    final nfc = nfcPresent ? ref.watch(nfcSupportProvider).value : null;
    final nfcReason = nfcUnavailableReason(l10n, nfc);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.emergencyTag_intro, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        EmergencyTagWarning(text: l10n.emergencyTag_warning),
        const SizedBox(height: 16),
        EmergencyTagTapSection(draft: draft, onChanged: _change),
        const SizedBox(height: 16),
        EmergencyTagFieldsSection(draft: draft, onChanged: _change),
        const SizedBox(height: 16),
        EmergencyTagPreview(draft: draft),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (nfcPresent)
              FilledButton.icon(
                key: const Key('emergencyTag_write'),
                onPressed: nfc == NfcSupport.enabled
                    ? () => showTagWriteSheet(
                        context,
                        request: TagWriteRequest(
                          fullUrl: draft.firstUri,
                          planFor: draft.planFor,
                          fieldLabel: emergencyTagDroppedLabel,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.nfc),
                label: Text(l10n.emergencyTag_write),
              ),
            Builder(
              builder: (anchor) => FilledButton.tonalIcon(
                key: const Key('emergencyTag_print'),
                onPressed: () => _print(anchor, draft),
                icon: const Icon(Icons.print),
                label: Text(l10n.emergencyTag_print),
              ),
            ),
          ],
        ),
        if (nfcPresent && nfcReason != null) ...[
          const SizedBox(height: 8),
          Text(nfcReason, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
