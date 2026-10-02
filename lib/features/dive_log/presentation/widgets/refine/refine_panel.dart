import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// The Refine panel (#2773). Replaced in full by the panel task.
class RefinePanel extends StatelessWidget {
  const RefinePanel({super.key, required this.filterProvider, this.onApplied});

  final StateProvider<DiveFilterState> filterProvider;
  final VoidCallback? onApplied;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
