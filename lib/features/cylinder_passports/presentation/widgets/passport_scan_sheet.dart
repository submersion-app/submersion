import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_mobile_scanner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

  /// The camera reports the same code many times a second; only the first
  /// may close the sheet, or a second pop would close the page under it.
  bool _done = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _finish(String text) {
    final value = text.trim();
    if (_done || value.isEmpty || !mounted) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    setState(() => _link.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camera = ref.watch(passportCameraProvider);
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
