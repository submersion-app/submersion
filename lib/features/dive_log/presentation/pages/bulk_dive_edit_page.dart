import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';

/// Thin wrapper that opens [DiveEditPage] in bulk-edit mode for [diveIds].
/// Mirrors `SiteMergePage` for the merge flow.
class BulkDiveEditPage extends StatelessWidget {
  const BulkDiveEditPage({super.key, required this.diveIds});

  final List<String> diveIds;

  @override
  Widget build(BuildContext context) {
    return DiveEditPage(bulkDiveIds: diveIds);
  }
}
