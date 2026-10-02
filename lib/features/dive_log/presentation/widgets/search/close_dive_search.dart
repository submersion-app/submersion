import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';

/// Closes the search row. Task 8 adds clearing with Undo.
void closeDiveSearch(BuildContext context, WidgetRef ref) {
  ref.read(diveSearchBarOpenProvider.notifier).state = false;
}
