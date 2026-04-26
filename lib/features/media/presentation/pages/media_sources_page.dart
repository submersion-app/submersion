import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Settings page listing all media sources.
///
/// Phase 1 only renders the platform photo library status and a
/// Diagnostics toggle that exposes the picker's hidden Files/URL tabs.
/// Phase 2 appends a Local files subsection; Phase 3 a Network Sources
/// subsection; Phase 4 a Connected Services subsection.
class MediaSourcesPage extends ConsumerWidget {
  const MediaSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Sources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('Photo library'),
                  subtitle: Text('Apple Photos / Google Photos / iCloud'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final shown = ref.watch(mediaPickerHiddenTabsProvider);
                    return ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: const Text('Show hidden picker tabs'),
                      subtitle: Text(
                        shown
                            ? 'Files and URL tabs visible in picker (debug)'
                            : 'Hidden by default',
                      ),
                      trailing: Switch(
                        value: shown,
                        onChanged: (v) =>
                            ref
                                    .read(
                                      mediaPickerHiddenTabsProvider.notifier,
                                    )
                                    .state =
                                v,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
