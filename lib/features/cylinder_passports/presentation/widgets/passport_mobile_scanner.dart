import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The live camera for the scan sheet: QR codes only, the first readable
/// value reported. The sheet guards against repeated reports.
class PassportMobileScanner extends StatefulWidget {
  const PassportMobileScanner({super.key, required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<PassportMobileScanner> createState() => _PassportMobileScannerState();
}

class _PassportMobileScannerState extends State<PassportMobileScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.isNotEmpty) {
            widget.onDetected(raw);
            return;
          }
        }
      },
      // A denied permission or a missing camera lands here; the sheet's
      // paste field stays usable below it.
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.l10n.passport_scan_cameraUnavailable,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
