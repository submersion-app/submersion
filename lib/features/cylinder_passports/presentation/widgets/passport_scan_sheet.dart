import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_tag_io.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/recent_passport_tags.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/nfc_availability_text.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_mobile_scanner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(PassportScanSheet);

/// Builds the live camera for the scan sheet; [onDetected] receives each
/// decoded QR value.
typedef PassportCameraBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onDetected);

/// The camera where `mobile_scanner` supports one (iOS, Android, macOS);
/// null elsewhere, where the sheet offers the paste field alone. Tests
/// override it so no real camera is ever opened.
final passportCameraProvider = Provider<PassportCameraBuilder?>((ref) {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.macOS =>
      (context, onDetected) => PassportMobileScanner(onDetected: onDetected),
    _ => null,
  };
});

/// Opens the scan sheet; resolves with the scanned or pasted text, or null
/// when the diver closed it.
Future<String?> showPassportScanSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const PassportScanSheet(),
      ),
    );

/// How every entry point opens the scan sheet. Overridden in tests.
final passportScanLauncherProvider =
    Provider<Future<String?> Function(BuildContext)>(
      (ref) => showPassportScanSheet,
    );

class PassportScanSheet extends ConsumerStatefulWidget {
  const PassportScanSheet({super.key});

  @override
  ConsumerState<PassportScanSheet> createState() => _PassportScanSheetState();
}

class _PassportScanSheetState extends ConsumerState<PassportScanSheet> {
  final _link = TextEditingController();
  late final NfcTagService _nfc = ref.read(nfcTagServiceProvider);
  bool _nfcReading = false;
  String? _nfcError;

  /// The camera reports the same code many times a second; only the first
  /// may close the sheet, or a second pop would close the page under it.
  bool _done = false;

  @override
  void dispose() {
    if (_nfcReading) unawaited(_nfc.cancel());
    _link.dispose();
    super.dispose();
  }

  void _finish(String text) {
    final value = text.trim();
    if (_done || value.isEmpty || !mounted) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  Future<void> _readNfc() async {
    final l10n = context.l10n;
    final recent = ref.read(recentPassportTagsProvider);
    setState(() {
      _nfcReading = true;
      _nfcError = null;
    });
    try {
      final result = await _nfc.withTag(
        promptIos: l10n.passport_nfc_holdNear,
        onTag: (tag) async {
          final read = await readPassportFrom(tag);
          // Noted while the session is open, before Android resumes its own
          // dispatch of the tag still held against the phone.
          if (read case TagReadText(:final text)) recent.note(text);
          return read;
        },
        iosEnd: (result) => switch (result) {
          TagReadText() => const IosSheetEnd.success(),
          TagHasNoPassport() => IosSheetEnd.failure(
            l10n.passport_tag_linkInvalid,
          ),
        },
        iosFailure: l10n.passport_nfc_readFailed,
      );
      if (!mounted) return;
      switch (result) {
        case TagReadText(:final text):
          _finish(text);
        case TagHasNoPassport():
          setState(() => _nfcError = l10n.passport_tag_linkInvalid);
      }
    } on NfcSessionCancelled {
      // The diver closed the system sheet: nothing to report.
    } on NfcSessionFailed catch (e) {
      // The system ended the session, usually a timeout with no tag
      // presented: expected, so not reported as an error.
      _log.info('NFC read session ended by the system: ${e.message}');
      if (mounted) setState(() => _nfcError = l10n.passport_nfc_readFailed);
    } catch (e, stackTrace) {
      _log.error('NFC read session failed', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _nfcError = l10n.passport_nfc_readFailed);
    } finally {
      if (mounted) setState(() => _nfcReading = false);
    }
  }

  Future<void> _paste() async {
    final ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException catch (e, stackTrace) {
      // Some platforms refuse clipboard access; the field still takes a
      // typed or long-press-pasted link, so this is a quiet no-op.
      _log.warning(
        'Could not read the clipboard',
        error: e,
        stackTrace: stackTrace,
      );
      return;
    }
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    setState(() => _link.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camera = ref.watch(passportCameraProvider);
    final nfc = ref.watch(nfcSupportProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.passport_scan_title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (camera != null) ...[
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: camera(context, _finish),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.passport_scan_hint),
          ] else
            Text(l10n.passport_scan_cameraUnavailable),
          // Shown on every platform; without NFC it is disabled with the
          // reason (spec 13.3).
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('passportScan_nfc'),
            icon: const Icon(Icons.nfc),
            label: Text(
              _nfcReading ? l10n.passport_nfc_holdNear : l10n.passport_nfc_tap,
            ),
            onPressed: nfc == NfcSupport.enabled && !_nfcReading
                ? _readNfc
                : null,
          ),
          if (nfcUnavailableReason(l10n, nfc) case final reason?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (_nfcError case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('passportScan_link'),
            controller: _link,
            keyboardType: TextInputType.url,
            onSubmitted: _finish,
            decoration: InputDecoration(
              labelText: l10n.passport_scan_linkLabel,
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: l10n.passport_scan_paste,
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => _finish(_link.text),
              child: Text(l10n.passport_scan_open),
            ),
          ),
        ],
      ),
    );
  }
}
