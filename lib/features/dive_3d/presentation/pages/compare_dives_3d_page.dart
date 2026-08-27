import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Standalone page for comparing several selected dives in 3D. Reached from
/// the dives-list multi-select "Compare in 3D" action.
class CompareDives3dPage extends ConsumerWidget {
  final List<String> diveIds;

  const CompareDives3dPage({super.key, required this.diveIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(
      diveComparisonProfilesProvider(DiveIdSet(diveIds)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_compare_dives_title)),
      body: CompareProfile3dView(
        profiles: profiles,
        initialLayout: CompareLayout.sideBySide,
      ),
    );
  }
}
