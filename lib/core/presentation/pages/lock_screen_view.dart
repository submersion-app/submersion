import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/core/presentation/widgets/unlock_form.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-screen startup lock: splash chrome around an UnlockForm plus the
/// escape-hatch links (recovery code / open a different database).
///
/// Rendered inside the splash MaterialApp, which carries the localization
/// delegates (see `StartupWrapper.build`), so `context.l10n` resolves here.
class LockScreenView extends StatelessWidget {
  final Brightness brightness;
  final Future<bool> Function(String secret) onSubmitSecret;
  final Future<bool> Function()? onBiometric;
  final VoidCallback? onUseRecoveryCode;
  final VoidCallback? onStartFresh;

  const LockScreenView({
    super.key,
    required this.brightness,
    required this.onSubmitSecret,
    required this.onBiometric,
    this.onUseRecoveryCode,
    this.onStartFresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OceanBackground(
        brightness: brightness,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.lock_screen_title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 32),
                  UnlockForm(
                    onSubmitSecret: onSubmitSecret,
                    onBiometric: onBiometric,
                    footer: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onUseRecoveryCode != null)
                          TextButton(
                            onPressed: onUseRecoveryCode,
                            child: Text(
                              context.l10n.lock_screen_forgotPassword,
                            ),
                          ),
                        if (onStartFresh != null)
                          TextButton(
                            onPressed: onStartFresh,
                            child: Text(context.l10n.lock_startFresh_title),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
