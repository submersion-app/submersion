import 'package:flutter/material.dart';

/// One route out of a terminal startup screen: what it does, and what it
/// costs.
///
/// The description is not decoration. Every one of these acts on the diver's
/// only dive log, from a screen they reached because something already went
/// wrong, so what each button will do has to be readable before it is pressed
/// rather than after.
class StartupRecoveryRoute extends StatelessWidget {
  const StartupRecoveryRoute({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    required this.textColor,
    required this.subtitleColor,
  });

  final IconData icon;
  final String label;
  final String description;

  /// Null renders the route disabled rather than removing it.
  final VoidCallback? onPressed;
  final Color textColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
