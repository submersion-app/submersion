import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';

import '../built_in_map_contract.dart';

/// The split pane's map and the built-in catalogue: everything it shares
/// with the phone's map page (see `built_in_map_contract.dart`).
void main() {
  builtInMapContract(
    map: () => Scaffold(body: SiteMapContent(onItemSelected: (_) {})),
  );
}
