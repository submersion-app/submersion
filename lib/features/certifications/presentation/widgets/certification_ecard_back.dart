import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

/// The back face of the certification card.
///
/// Shows the uploaded rear photo when the diver captured one, otherwise a
/// generated design carrying the instructor details.
class CertificationEcardBack extends StatelessWidget {
  /// The certification to display.
  final Certification certification;

  const CertificationEcardBack({super.key, required this.certification});

  @override
  Widget build(BuildContext context) {
    final photo = certification.photoBack;
    if (photo != null) {
      return CertificationCardPhoto(bytes: photo);
    }
    return _buildGeneratedBack(context);
  }

  Widget _buildGeneratedBack(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          CertificationCardPhoto.borderRadius,
        ),
        color: const Color(0xFFE0E0E0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Magnetic stripe
          const SizedBox(height: 24),
          Container(height: 40, color: const Color(0xFF424242)),
          const SizedBox(height: 16),
          // Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructor info
                  if (certification.instructorName != null &&
                      certification.instructorName!.isNotEmpty) ...[
                    Text(
                      context.l10n.certifications_ecard_label_instructor,
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      certification.instructorName!,
                      style: const TextStyle(
                        color: Color(0xFF424242),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (certification.instructorNumber != null &&
                      certification.instructorNumber!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '#${certification.instructorNumber}',
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Certified by agency
                  Center(
                    child: Text(
                      context.l10n.certifications_ecard_label_certifiedBy(
                        certification.agency.displayName,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
