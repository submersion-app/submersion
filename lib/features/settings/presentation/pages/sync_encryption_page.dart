import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/encryption_settings_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Today's end-to-end encryption section on a page of its own, under the
/// Sync page's Advanced fold (spec section 8.1). Same dialogs inside.
class SyncEncryptionPage extends StatelessWidget {
  const SyncEncryptionPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.settings_sync_encryption)),
    body: ListView(children: const [EncryptionSettingsSection()]),
  );
}
