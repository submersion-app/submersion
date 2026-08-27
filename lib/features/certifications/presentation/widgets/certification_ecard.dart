import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_back.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_front.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A credit card-style widget displaying a certification with agency branding.
///
/// Supports both front and back views with an animated flip transition. Each
/// face shows the diver's uploaded photo of that side when one exists, and a
/// generated design otherwise.
class CertificationEcard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));

    // Spoken, not printed: the screen reader label has no width budget, so it
    // carries the diver's full date rather than the card face's compact form.
    // A bare "03/18" would be read against whichever order the diver expects.
    final issueDateStr = certification.issueDate != null
        ? ', issued ${units.formatDate(certification.issueDate)}'
        : '';
    final statusStr = certification.isExpired
        ? ', Expired'
        : certification.expiresWithin(90)
        ? ', Expiring soon'
        : '';

    return Semantics(
      label:
          '${certification.agency.displayName} ${certificationTitle(certification)} certification for $diverName$issueDateStr$statusStr. ${showBack ? 'Showing back' : 'Showing front'}. Tap to flip',
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
                ? CertificationEcardBack(
                    key: const ValueKey('back'),
                    certification: certification,
                  )
                : CertificationEcardFront(
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
