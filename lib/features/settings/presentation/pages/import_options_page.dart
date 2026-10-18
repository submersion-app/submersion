import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/import_preferences_group.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data > Advanced > Import options (issue #3482): the import
/// preferences that used to sit inline on the Data page, unchanged.
class ImportOptionsPage extends StatelessWidget {
  const ImportOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_data_importOptions)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [ImportPreferencesGroup()],
      ),
    );
  }
}
