import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';

class SiteMergePage extends StatelessWidget {
  final List<String> siteIds;

  const SiteMergePage({super.key, required this.siteIds});

  @override
  Widget build(BuildContext context) {
    return SiteEditPage(mergeSiteIds: siteIds);
  }
}
