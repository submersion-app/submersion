import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/presentation/widgets/appearance_settings_tiles.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Appearance on a phone. The tablet and desktop settings pane
/// renders the same tiles from appearance_settings_tiles.dart.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_appearance_title),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_general,
          ),
          AppearanceGeneralTiles(
            separator: const Divider(),
            onLanguageTap: () => context.push('/settings/language'),
          ),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_colorAccents,
          ),
          const AppearanceAccentTiles(),
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_sections,
          ),
          AppearanceSectionTiles(
            onSectionTap: (key) =>
                context.push('/settings/appearance/${_routeSegment(key)}'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// The route segment under /settings/appearance for a section key.
  static String _routeSegment(String key) =>
      key == 'diveCenters' ? 'dive-centers' : key;

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
