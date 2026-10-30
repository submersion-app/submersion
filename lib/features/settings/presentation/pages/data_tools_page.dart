import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/data_row_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data > Advanced > Data tools (issue #3482): the four one-off
/// repair tools that used to sit at the bottom of the Data page. Each row
/// still opens the same page it opened there.
class DataToolsPage extends StatelessWidget {
  const DataToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget tool(IconData icon, String title, String subtitle, String route) =>
        DataRowTile(icon: icon, title: title, subtitle: subtitle, route: route);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_data_dataTools)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          tool(
            Icons.access_time,
            l10n.settings_fixDiveTimes_title,
            l10n.settings_fixDiveTimes_subtitle,
            '/settings/fix-dive-times',
          ),
          tool(
            Icons.group_add,
            l10n.buddies_linkText_page_title,
            l10n.buddies_linkText_page_subtitle,
            '/settings/link-buddy-names',
          ),
          tool(
            Icons.category,
            l10n.equipment_retypeOther_title,
            l10n.equipment_retypeOther_subtitle,
            '/settings/retype-other-gear',
          ),
          tool(
            Icons.rule,
            l10n.dataQuality_settings_title,
            l10n.dataQuality_settings_subtitle,
            '/settings/data-quality',
          ),
        ],
      ),
    );
  }
}
