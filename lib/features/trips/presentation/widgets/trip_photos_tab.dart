import 'package:flutter/material.dart';

import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';

/// The Photos tab: the trip's photo section on its own scroll.
class TripPhotosTab extends StatelessWidget {
  final String tripId;

  const TripPhotosTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TripPhotoSection(tripId: tripId),
    );
  }
}
