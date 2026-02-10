import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// A credit card-style widget displaying a certification with agency branding.
///
/// Supports both front and back views with an animated flip transition.
class CertificationEcard extends StatelessWidget {
  /// The certification to display.
  final Certification certification;

  /// The name of the diver holding this certification.
  final String diverName;

  /// Whether to show the back of the card (default: false).
  final bool showBack;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Standard credit card aspect ratio (CR80 format).
  static const double aspectRatio = 1.586;

  const CertificationEcard({
    super.key,
    required this.certification,
    required this.diverName,
    this.showBack = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final issueDateStr = certification.issueDate != null
        ? ', issued ${DateFormat('MM/yy').format(certification.issueDate!)}'
        : '';
    final statusStr = certification.isExpired
        ? ', Expired'
        : certification.expiresWithin(90)
        ? ', Expiring soon'
        : '';

    return Semantics(
      label:
          '${certification.agency.displayName} ${certification.name} certification for $diverName$issueDateStr$statusStr. ${showBack ? 'Showing back' : 'Showing front'}. Tap to flip',
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: showBack
                ? _CardBack(
                    key: const ValueKey('back'),
                    certification: certification,
                  )
                : _CardFront(
                    key: const ValueKey('front'),
                    certification: certification,
                    diverName: diverName,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The front face of the certification card.
class _CardFront extends StatelessWidget {
  final Certification certification;
  final String diverName;

  const _CardFront({
    super.key,
    required this.certification,
    required this.diverName,
  });

  @override
  Widget build(BuildContext context) {
    final agency = certification.agency;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [agency.primaryColor, agency.secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: agency.primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative wave pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _WavePatternPainter(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: agency name and status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        agency.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),
                const Spacer(),
                // Center: certification name
                Text(
                  certification.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Level display if present
                if (certification.level != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    certification.level!.displayName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const Spacer(),
                // Bottom row: diver info and issue date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            diverName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (certification.cardNumber != null &&
                              certification.cardNumber!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              certification.cardNumber!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (certification.issueDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ISSUED',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat(
                              'MM/yy',
                            ).format(certification.issueDate!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (certification.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'EXPIRED',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    if (certification.expiresWithin(90)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'EXPIRING',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// The back face of the certification card.
class _CardBack extends StatelessWidget {
  final Certification certification;

  const _CardBack({super.key, required this.certification});

  @override
  Widget build(BuildContext context) {
    // If there's a photo of the back, show it
    if (certification.photoBack != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(certification.photoBack!, fit: BoxFit.cover),
      );
    }

    // Generate a back design
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
                    const Text(
                      'INSTRUCTOR',
                      style: TextStyle(
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
                      'Certified by ${certification.agency.displayName}',
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

/// Custom painter for decorative wave pattern on the card.
class _WavePatternPainter extends CustomPainter {
  final Color color;

  _WavePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw decorative circles at various positions
    final circles = [
      (Offset(size.width * 0.85, size.height * 0.2), size.width * 0.25),
      (Offset(size.width * 0.95, size.height * 0.6), size.width * 0.18),
      (Offset(size.width * 0.1, size.height * 0.9), size.width * 0.15),
      (Offset(size.width * 0.75, size.height * 0.85), size.width * 0.12),
    ];

    for (final (offset, radius) in circles) {
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
