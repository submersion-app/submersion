import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';

class BuddyMergePage extends StatelessWidget {
  final List<String> buddyIds;

  const BuddyMergePage({super.key, required this.buddyIds});

  @override
  Widget build(BuildContext context) {
    return BuddyEditPage(mergeBuddyIds: buddyIds);
  }
}
