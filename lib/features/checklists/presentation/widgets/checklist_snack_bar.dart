import 'package:flutter/material.dart';

/// Shows the checklists feature's confirmation or error on [messenger], which
/// callers capture before an await so the message survives their context.
void showChecklistSnackBar(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      showCloseIcon: true,
    ),
  );
}
