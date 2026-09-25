import 'package:flutter/material.dart';

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';

class DivelogsSignInStep extends StatelessWidget {
  const DivelogsSignInStep({super.key, required this.onSignedIn});

  final ValueChanged<DivelogsApiClient?> onSignedIn;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class DivelogsFetchStep extends StatelessWidget {
  const DivelogsFetchStep({
    super.key,
    required this.client,
    required this.onPhotosListed,
  });

  final DivelogsApiClient? client;
  final ValueChanged<Map<String, List<RemotePhoto>>> onPhotosListed;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
